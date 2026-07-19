import SwiftUI

/// Shared "Price per gram" form section: manual entry, currency picker,
/// and a one-tap fetch of today's price (manual edits always win).
struct GoldPriceSection: View {
    /// Show the gold price field (hidden for silver-only calculations).
    var includeGold = true
    /// Show the silver price field too.
    var includeSilver = false

    @AppStorage("goldPrice24kText") private var priceText = ""
    @AppStorage("silverPriceText") private var silverPriceText = ""
    @AppStorage("goldPriceCurrency") private var currencyCode = "SAR"
    @AppStorage("goldPriceUpdatedAt") private var updatedAtTimestamp = 0.0
    /// True while the stored price came from a fetch (safe to auto-refresh).
    @AppStorage("goldPriceWasFetched") private var wasFetched = false

    @State private var fetching = false
    @State private var fetchFailed = false
    @State private var settingProgrammatically = false

    /// Fetched prices go stale after this long and refresh on appear.
    private let staleAfter: TimeInterval = 15 * 60

    private static let currencies = ["SAR", "USD", "AED", "PKR", "INR", "EGP", "EUR"]

    var body: some View {
        Section("Price per gram") {
            if includeGold {
                LabeledContent("Gold price") {
                    TextField("Price", text: $priceText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: priceText) { _, new in
                            let s = new.sanitizedDecimal
                            if s != new { priceText = s }
                            // A hand-typed price must never be auto-overwritten.
                            if !settingProgrammatically { wasFetched = false }
                        }
                }
            }
            if includeSilver {
                LabeledContent("Silver") {
                    TextField("Price", text: $silverPriceText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: silverPriceText) { _, new in
                            let s = new.sanitizedDecimal
                            if s != new { silverPriceText = s }
                        }
                }
            }
            Picker("Currency", selection: $currencyCode) {
                ForEach(Self.currencies, id: \.self) { Text($0) }
            }
            .onChange(of: currencyCode) { _, _ in
                Task { await fetch() }
            }
            Button {
                Task { await fetch() }
            } label: {
                HStack {
                    Label("Fetch today's price", systemImage: "arrow.clockwise")
                    if fetching {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(fetching)

            if fetchFailed {
                Text("Couldn't fetch the gold price. Enter it manually.")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if includeGold && !wasFetched && !priceText.isEmpty {
                Text("Manual price — auto-update paused")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if updatedAtTimestamp > 0 {
                Text("Updated \(Date(timeIntervalSince1970: updatedAtTimestamp).formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            // Fetch when empty, or refresh a fetched price that's gone stale.
            // Hand-typed prices (wasFetched == false) are never clobbered.
            let stale = Date.now.timeIntervalSince1970 - updatedAtTimestamp > staleAfter
            if priceText.isEmpty || (wasFetched && stale) {
                await fetch()
            }
        }
    }

    private func fetch() async {
        guard !fetching else { return }
        fetching = true
        fetchFailed = false
        defer { fetching = false }

        settingProgrammatically = true
        defer { settingProgrammatically = false }
        if includeGold {
            if let price = await GoldPriceService.pricePerGram24k(currency: currencyCode) {
                priceText = "\(price)"
                updatedAtTimestamp = Date.now.timeIntervalSince1970
                wasFetched = true
            } else {
                fetchFailed = true
            }
        }
        if includeSilver {
            if let silver = await GoldPriceService.silverPricePerGram(currency: currencyCode) {
                silverPriceText = "\(silver)"
                updatedAtTimestamp = Date.now.timeIntervalSince1970
            } else if !includeGold {
                fetchFailed = true
            }
        }
    }
}
