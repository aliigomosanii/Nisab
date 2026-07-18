import SwiftUI

/// Shared "Price per gram" form section: manual entry, currency picker,
/// and a one-tap fetch of today's price (manual edits always win).
struct GoldPriceSection: View {
    @AppStorage("goldPrice24kText") private var priceText = ""
    @AppStorage("goldPriceCurrency") private var currencyCode = "SAR"
    @AppStorage("goldPriceUpdatedAt") private var updatedAtTimestamp = 0.0

    @State private var fetching = false
    @State private var fetchFailed = false

    private static let currencies = ["SAR", "USD", "AED", "PKR", "INR", "EGP", "EUR"]

    var body: some View {
        Section("Price per gram") {
            TextField("Today's 24k price per gram", text: $priceText)
                .keyboardType(.decimalPad)
                .onChange(of: priceText) { _, new in
                    let s = new.sanitizedDecimal
                    if s != new { priceText = s }
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
            } else if updatedAtTimestamp > 0 {
                Text("Updated \(Date(timeIntervalSince1970: updatedAtTimestamp).formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            // Pre-fill only when empty so a manual price is never clobbered.
            if priceText.isEmpty {
                await fetch()
            }
        }
    }

    private func fetch() async {
        guard !fetching else { return }
        fetching = true
        fetchFailed = false
        defer { fetching = false }

        if let price = await GoldPriceService.pricePerGram24k(currency: currencyCode) {
            priceText = "\(price)"
            updatedAtTimestamp = Date.now.timeIntervalSince1970
        } else {
            fetchFailed = true
        }
    }
}
