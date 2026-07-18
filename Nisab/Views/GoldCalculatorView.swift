import SwiftUI
import SwiftData

/// Gold zakat calculator. Combines an optional manual entry with any
/// selected Gold Wallet items — everything is converted to pure-gold
/// grams, so mixed karats add up correctly against one 24k price.
struct GoldCalculatorView: View {
    @Query(sort: \GoldItem.purchaseDate, order: .reverse) private var allItems: [GoldItem]

    /// Paid items are ignored until their Hijri year passes; the gold
    /// calculator only offers gold-bearing items (gold and diamond settings).
    private var items: [GoldItem] {
        allItems.filter { !$0.isZakatExempt && $0.material != .silver }
    }

    @State private var weightText = ""
    @State private var karat = 24
    @State private var selectedIDs: Set<UUID> = []
    @State private var walletListExpanded = false
    // Shared with the Gold Wallet so the price is entered once.
    @AppStorage("goldPrice24kText") private var priceText = ""
    @AppStorage("goldPriceCurrency") private var currencyCode = "SAR"

    private static let currencies = ["SAR", "USD", "AED", "PKR", "INR", "EGP", "EUR"]

    private var manualPureGrams: Decimal {
        (Decimal(string: weightText) ?? 0) * Decimal(karat) / 24
    }

    private var selectedPureGrams: Decimal {
        items.filter { selectedIDs.contains($0.id) }
            .reduce(0) { $0 + $1.pureGoldGrams }
    }

    private var totalPureGrams: Decimal { manualPureGrams + selectedPureGrams }

    /// Raw (actual) weight: manual entry + selected wallet items.
    private var totalWeightGrams: Decimal {
        (Decimal(string: weightText) ?? 0)
            + items.filter { selectedIDs.contains($0.id) }.reduce(0) { $0 + $1.weightGrams }
    }
    private var price24k: Decimal? { Decimal(string: priceText) }
    private var totalValue: Decimal? { price24k.map { totalPureGrams * $0 } }
    private var aboveNisab: Bool { totalPureGrams >= Zakat.nisabGrams }
    private var zakatGrams: Decimal? { aboveNisab ? totalPureGrams * Zakat.rate : nil }
    private var zakatDue: Decimal? {
        guard aboveNisab else { return nil }
        return totalValue.map { $0 * Zakat.rate }
    }

    /// Selectable wallet items shown inside the disclosure group.
    private var walletRows: some View {
        ForEach(items) { item in
            Button {
                if selectedIDs.contains(item.id) {
                    selectedIDs.remove(item.id)
                } else {
                    selectedIDs.insert(item.id)
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name.isEmpty ? item.summaryLine : item.name)
                            .foregroundStyle(.primary)
                        if !item.name.isEmpty {
                            Text(item.summaryLine)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: selectedIDs.contains(item.id)
                          ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedIDs.contains(item.id) ? Color.accentColor : .secondary)
                }
            }
        }
    }

    var body: some View {
        Form {
            Section("Gold") {
                TextField("Weight (grams)", text: $weightText)
                    .onAppear {
                        karat = UserDefaults.standard.object(forKey: "defaultKarat") as? Int ?? 24
                    }
                    .keyboardType(.decimalPad)
                    .onChange(of: weightText) { _, new in
                        let s = new.sanitizedDecimal
                        if s != new { weightText = s }
                    }
                Picker("Karat", selection: $karat) {
                    ForEach(Zakat.karats, id: \.self) { Text("\($0)K") }
                }
            }

            if !items.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $walletListExpanded) {
                        walletRows
                    } label: {
                        Text("Add from Gold Wallet")
                    }
                }
            }

            GoldPriceSection()

            if totalPureGrams > 0 {
                Section("Result") {
                    LabeledContent("Total weight") {
                        Text("\(totalWeightGrams.formatted(.number.precision(.fractionLength(0...2)))) g")
                    }
                    LabeledContent("Pure gold equivalent") {
                        Text("\(totalPureGrams.formatted(.number.precision(.fractionLength(0...2)))) g")
                    }
                    if let totalValue {
                        LabeledContent("Gold value", value: totalValue.formatted(.currency(code: currencyCode)))
                    }
                    LabeledContent("Nisab (85g pure gold)") {
                        Text(aboveNisab ? "Above nisab" : "Below nisab")
                            .foregroundStyle(aboveNisab ? Color.green : .red)
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
                }

                Section {
                    Text("Zakat is due when your pure gold reaches the nisab (85g) and has been held for one lunar year (hawl).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack { GoldCalculatorView() }
        .modelContainer(for: [GoldItem.self], inMemory: true)
}
