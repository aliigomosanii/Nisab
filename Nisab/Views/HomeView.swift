import SwiftUI
import SwiftData

/// Tejoury home: personalized greeting plus a live dashboard card
/// for every feature.
struct HomeView: View {
    @Query(sort: \GoldItem.purchaseDate, order: .reverse) private var items: [GoldItem]
    @AppStorage("profileName") private var profileName = ""
    @AppStorage("goldPrice24kText") private var storedGoldPrice = ""
    @AppStorage("silverPriceText") private var storedSilverPrice = ""
    @AppStorage("goldPriceCurrency") private var priceCurrency = "SAR"
    @State private var showingSettings = false
    @State private var showingPayZakat = false

    private var eligible: [GoldItem] { items.filter { !$0.isZakatExempt } }
    private var totalWeight: Decimal { items.reduce(0) { $0 + $1.weightGrams } }

    /// Aggregate hawl: due one Hijri year after holdings crossed nisab.
    private var goldDue: Date? { items.goldZakatDueDate() }
    private var silverDue: Date? { items.silverZakatDueDate() }

    private var anyDueNow: Bool {
        [goldDue, silverDue].compactMap { $0 }.contains { $0 <= .now }
    }

    private var nextDue: Date? {
        var candidates = [goldDue, silverDue].compactMap { $0 }.filter { $0 > .now }
        candidates += items.filter(\.isZakatExempt).compactMap(\.zakatExemptUntil)
        return candidates.min()
    }

    /// Same figure the wallet shows: expected selling prices summed across
    /// items whose needed metal price is available.
    private var totalWorth: Decimal? {
        let gold = Decimal(string: storedGoldPrice)
        let silver = Decimal(string: storedSilverPrice)
        let values = items.compactMap {
            $0.expectedSellingPrice(goldPricePerGram24k: gold, silverPricePerGram: silver)
        }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }

    private var initials: String {
        profileName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
    }

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    profileHeader

                    LazyVGrid(columns: columns, spacing: 12) {
                        NavigationLink {
                            GoldWalletView()
                                .navigationTitle("Jewelry Wallet")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            card("Jewelry Wallet", caption: "Your jewelry items", icon: "circle.hexagongrid.fill") {
                                if !items.isEmpty {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(items.count) items · \(totalWeight.formatted(.number.precision(.fractionLength(0...2)))) g")
                                            .foregroundStyle(Color.accentColor)
                                        if let worth = totalWorth {
                                            Text(worth.formatted(.currency(code: priceCurrency)))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            GoldCalculatorView()
                                .navigationTitle("Zakat Calculator")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            // "Due now" lives on the actionable card
                            // (Record Zakat Payment) only.
                            card("Zakat Calculator", caption: "Calculate what's due", icon: "moon.stars.fill") {
                                EmptyView()
                            }
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            BuySellCalculatorView()
                                .navigationTitle("Buy & Sell Calculator")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            card("Buy & Sell Calculator", caption: "Estimate buying and selling prices", icon: "arrow.left.arrow.right.circle.fill") {
                                if let gold = Decimal(string: storedGoldPrice) {
                                    Text("Gold price: \(gold.formatted(.currency(code: priceCurrency)))")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        Button {
                            showingPayZakat = true
                        } label: {
                            card("Record Zakat Payment", caption: "Record a payment", icon: "checkmark.seal.fill") {
                                if anyDueNow {
                                    Text("Due now")
                                        .foregroundStyle(.orange)
                                } else if let nextDue {
                                    Text("Next: \(nextDue.hijriString)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tejoury")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingPayZakat) {
                PayZakatView(items: eligible)
            }
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.gradient)
                    .frame(width: 52, height: 52)
                if initials.isEmpty {
                    Image(systemName: "person.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                } else {
                    Text(initials)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                if profileName.isEmpty {
                    Text("Salam!")
                        .font(.title3.bold())
                } else {
                    Text("Salam, \(profileName)!")
                        .font(.title3.bold())
                        .lineLimit(1)
                }
                Text(Date.now.dualCalendarString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if profileName.isEmpty {
                    Button("Set up your profile") {
                        showingSettings = true
                    }
                    .font(.caption.bold())
                }
            }
            Spacer()
        }
    }

    private func card(
        _ title: LocalizedStringKey,
        caption: LocalizedStringKey,
        icon: String,
        @ViewBuilder status: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.leading)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            status()
                .font(.caption.bold())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        // Fixed height keeps all four cards identical; the spacer pins
        // the live status line to the bottom edge.
        .frame(height: 160)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [GoldItem.self], inMemory: true)
}
