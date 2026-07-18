import SwiftUI
import SwiftData

/// The user's owned gold, with a live zakat estimate based on today's price.
struct GoldWalletView: View {
    @Query(sort: \GoldItem.purchaseDate, order: .reverse) private var items: [GoldItem]
    @AppStorage("goldPrice24kText") private var priceText = ""
    @AppStorage("goldPriceCurrency") private var currencyCode = "SAR"
    @State private var showingAdd = false
    @State private var showingPayZakat = false

    private static let currencies = ["SAR", "USD", "AED", "PKR", "INR", "EGP", "EUR"]

    /// Items that count toward zakat (not inside a paid lunar year).
    private var eligible: [GoldItem] { items.filter { !$0.isZakatExempt } }
    private var exempt: [GoldItem] { items.filter(\.isZakatExempt) }

    private var totalWeight: Decimal { items.reduce(0) { $0 + $1.weightGrams } }
    private var pureGrams: Decimal { eligible.reduce(0) { $0 + $1.pureGoldGrams } }
    private var exemptPureGrams: Decimal { exempt.reduce(0) { $0 + $1.pureGoldGrams } }

    // Silver runs on its own nisab and price.
    @AppStorage("silverPriceText") private var silverPriceText = ""
    private var hasSilver: Bool { items.contains { $0.material == .silver } }
    private var silverGrams: Decimal { eligible.reduce(0) { $0 + $1.silverGrams } }
    private var silverPrice: Decimal? { Decimal(string: silverPriceText) }
    private var silverAboveNisab: Bool { silverGrams >= Zakat.silverNisabGrams }
    private var silverZakatGrams: Decimal? {
        silverAboveNisab ? silverGrams * Zakat.rate : nil
    }
    private var silverZakatValue: Decimal? {
        guard silverAboveNisab else { return nil }
        return silverPrice.map { silverGrams * $0 * Zakat.rate }
    }
    private var price24k: Decimal? { Decimal(string: priceText) }
    private var totalValue: Decimal? { price24k.map { pureGrams * $0 } }
    private var aboveNisab: Bool { pureGrams >= Zakat.nisabGrams }
    /// Zakat expressed in grams of pure gold — computable even without a price.
    private var zakatGrams: Decimal? {
        aboveNisab ? pureGrams * Zakat.rate : nil
    }
    /// Zakat in currency — needs today's price.
    private var zakatDue: Decimal? {
        guard aboveNisab else { return nil }
        return totalValue.map { $0 * Zakat.rate }
    }

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "No jewelry yet",
                    systemImage: "circle.hexagongrid.fill",
                    description: Text("Tap + to add your jewelry")
                )
            } else {
                List {
                    GoldPriceSection(includeSilver: hasSilver)
                    Section("Zakat") {
                        LabeledContent("Total weight") {
                            Text("\(totalWeight.formatted(.number.precision(.fractionLength(0...2)))) g")
                        }
                        LabeledContent("Pure gold equivalent") {
                            Text("\(pureGrams.formatted(.number.precision(.fractionLength(0...2)))) g")
                        }
                        LabeledContent("Nisab (85g pure gold)") {
                            Text(aboveNisab ? "Above nisab" : "Below nisab")
                                .foregroundStyle(aboveNisab ? Color.green : .red)
                        }
                        if let totalValue {
                            LabeledContent("Gold value", value: totalValue.formatted(.currency(code: currencyCode)))
                        }
                        if let zakatGrams {
                            LabeledContent("Zakat due (2.5%)") {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(zakatGrams.formatted(.number.precision(.fractionLength(0...2)))) g")
                                        .bold()
                                        .foregroundStyle(.orange)
                                    if let zakatDue {
                                        Text(zakatDue.formatted(.currency(code: currencyCode)))
                                            .bold()
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                            if price24k == nil {
                                Text("Enter today's gold price to value your zakat in currency.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("No zakat due")
                                .foregroundStyle(.secondary)
                        }
                        if hasSilver {
                            LabeledContent("Total silver") {
                                Text("\(silverGrams.formatted(.number.precision(.fractionLength(0...2)))) g")
                            }
                            LabeledContent("Silver nisab (595g)") {
                                Text(silverAboveNisab ? "Above nisab" : "Below nisab")
                                    .foregroundStyle(silverAboveNisab ? Color.green : .red)
                            }
                            if let silverZakatGrams {
                                LabeledContent("Silver zakat due (2.5%)") {
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(silverZakatGrams.formatted(.number.precision(.fractionLength(0...2)))) g")
                                            .bold()
                                            .foregroundStyle(.orange)
                                        if let silverZakatValue {
                                            Text(silverZakatValue.formatted(.currency(code: currencyCode)))
                                                .bold()
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                }
                            }
                        }
                        if !exempt.isEmpty {
                            LabeledContent("Excluded (zakat paid)") {
                                Text("\(exemptPureGrams.formatted(.number.precision(.fractionLength(0...2)))) g")
                            }
                        }
                    }

                    Section("Jewelry") {
                        ForEach(items) { item in
                            NavigationLink(value: item.id) {
                                GoldRow(item: item)
                            }
                        }
                    }

                    Section {
                        Text("Zakat is due when your pure gold reaches the nisab (85g) and has been held for one lunar year (hawl).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationDestination(for: UUID.self) { id in
            if let item = items.first(where: { $0.id == id }) {
                GoldItemDetailView(item: item)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add Jewelry Item", systemImage: "plus.circle")
                    }
                    if !eligible.isEmpty {
                        Button {
                            showingPayZakat = true
                        } label: {
                            Label("Record Zakat Payment", systemImage: "checkmark.seal")
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Jewelry Item")
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddGoldItemView()
        }
        .sheet(isPresented: $showingPayZakat) {
            PayZakatView(items: eligible)
        }
    }
}

private struct GoldRow: View {
    let item: GoldItem

    var body: some View {
        HStack(spacing: 10) {
            if let data = item.itemImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.summaryLine)
                        .font(.headline)
                    Text(item.material.title)
                        .font(.caption2.bold())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                }
                Text(item.purchaseDate.dualCalendarString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if item.isZakatExempt, let until = item.zakatExemptUntil {
                    Text("Zakat paid until \(until.hijriString)")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.purchasePrice.formatted(.currency(code: item.currencyCode)))
                    .font(.subheadline)
                if item.invoiceImageData != nil {
                    Image(systemName: "doc.text.image")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
