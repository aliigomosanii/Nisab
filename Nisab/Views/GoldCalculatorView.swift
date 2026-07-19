import SwiftUI
import SwiftData

/// The Zakat Calculator: manual entry (gold, silver, or diamond) plus any
/// selected Jewelry Wallet items, computed on separate gold and silver
/// tracks with their own nisab thresholds and prices.
struct GoldCalculatorView: View {
    @Query(sort: \GoldItem.purchaseDate, order: .reverse) private var allItems: [GoldItem]

    @State private var material: JewelryMaterial = .gold
    @State private var weightText = ""
    @State private var karat = 24
    @State private var selectedIDs: Set<UUID> = []
    @State private var walletListExpanded = false
    @AppStorage("goldPrice24kText") private var priceText = ""
    @AppStorage("silverPriceText") private var silverPriceText = ""
    @AppStorage("goldPriceCurrency") private var currencyCode = "SAR"

    /// Paid items are ignored until their Hijri year passes.
    private var walletItems: [GoldItem] { allItems.filter { !$0.isZakatExempt } }
    private var exemptItems: [GoldItem] { allItems.filter(\.isZakatExempt) }
    private var selectedItems: [GoldItem] { walletItems.filter { selectedIDs.contains($0.id) } }

    // MARK: - Manual entry

    private var weight: Decimal { Decimal(string: weightText) ?? 0 }
    private var manualGoldPure: Decimal {
        material == .silver ? 0 : weight * Decimal(karat) / 24
    }
    private var manualSilver: Decimal {
        material == .silver ? weight : 0
    }

    // MARK: - Totals (manual + selected wallet items)

    private var goldPureGrams: Decimal {
        manualGoldPure + selectedItems.reduce(0) { $0 + $1.pureGoldGrams }
    }
    private var silverGrams: Decimal {
        manualSilver + selectedItems.reduce(0) { $0 + $1.silverGrams }
    }

    private var goldPrice: Decimal? { Decimal(string: priceText) }
    private var silverPrice: Decimal? { Decimal(string: silverPriceText) }

    private var goldAboveNisab: Bool { goldPureGrams >= Zakat.nisabGrams }
    private var silverAboveNisab: Bool { silverGrams >= Zakat.silverNisabGrams }

    private var goldZakatGrams: Decimal? { goldAboveNisab ? goldPureGrams * Zakat.rate : nil }
    private var goldZakatValue: Decimal? {
        guard goldAboveNisab else { return nil }
        return goldPrice.map { goldPureGrams * $0 * Zakat.rate }
    }
    private var silverZakatGrams: Decimal? { silverAboveNisab ? silverGrams * Zakat.rate : nil }
    private var silverZakatValue: Decimal? {
        guard silverAboveNisab else { return nil }
        return silverPrice.map { silverGrams * $0 * Zakat.rate }
    }

    /// A metal's price field only appears when that metal is actually in
    /// the calculation (manual entry or a selected wallet item).
    private var goldRelevant: Bool {
        material != .silver || selectedItems.contains { $0.material != .silver }
    }
    private var silverRelevant: Bool {
        material == .silver || selectedItems.contains { $0.material == .silver }
    }

    var body: some View {
        Form {
            Section("Material") {
                Picker("Material", selection: $material) {
                    ForEach(JewelryMaterial.selectable) { m in
                        Text(m.title).tag(m)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                decimalField("Weight (grams)", text: $weightText)
                if material == .gold {
                    karatPicker("Karat")
                }
            }

            if !walletItems.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $walletListExpanded) {
                        walletRows
                    } label: {
                        Text("Add from Jewelry Wallet")
                    }
                }
            }

            GoldPriceSection(includeGold: goldRelevant, includeSilver: silverRelevant)

            if goldPureGrams > 0 {
                Section("Gold") {
                    LabeledContent("Pure gold equivalent") {
                        Text("\(goldPureGrams.formatted(.number.precision(.fractionLength(0...2)))) g")
                    }
                    if let goldPrice {
                        LabeledContent("Gold value", value: (goldPureGrams * goldPrice).formatted(.currency(code: currencyCode)))
                    }
                    LabeledContent("Nisab (85g pure gold)") {
                        Text(goldAboveNisab ? "Above nisab" : "Below nisab")
                            .foregroundStyle(goldAboveNisab ? Color.green : .red)
                    }
                    if let goldZakatGrams {
                        LabeledContent("Zakat due (2.5%)") {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(goldZakatGrams.formatted(.number.precision(.fractionLength(0...2)))) g")
                                    .bold()
                                    .foregroundStyle(.orange)
                                if let goldZakatValue {
                                    Text(goldZakatValue.formatted(.currency(code: currencyCode)))
                                        .bold()
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    } else {
                        Text("No zakat due")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if silverGrams > 0 {
                Section("Silver") {
                    LabeledContent("Total silver") {
                        Text("\(silverGrams.formatted(.number.precision(.fractionLength(0...2)))) g")
                    }
                    if let silverPrice {
                        LabeledContent("Silver value", value: (silverGrams * silverPrice).formatted(.currency(code: currencyCode)))
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
                    } else {
                        Text("No zakat due")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !exemptItems.isEmpty {
                Section {
                    let exemptGold = exemptItems.reduce(Decimal(0)) { $0 + $1.pureGoldGrams }
                    let exemptSilver = exemptItems.reduce(Decimal(0)) { $0 + $1.silverGrams }
                    if exemptGold > 0 {
                        LabeledContent("Excluded (zakat paid)") {
                            Text("\(exemptGold.formatted(.number.precision(.fractionLength(0...2)))) g")
                        }
                    }
                    if exemptSilver > 0 {
                        LabeledContent("Excluded silver (zakat paid)") {
                            Text("\(exemptSilver.formatted(.number.precision(.fractionLength(0...2)))) g")
                        }
                    }
                }
            }

            if goldPureGrams > 0 || silverGrams > 0 {
                Section {
                    Text("Zakat is due when your gold reaches its nisab (85g pure) or your silver reaches its nisab (595g), and has been held for one lunar year (hawl).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Pieces

    private var walletRows: some View {
        ForEach(walletItems) { item in
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

    private func decimalField(_ title: LocalizedStringKey, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .keyboardType(.decimalPad)
            .onChange(of: text.wrappedValue) { _, new in
                let s = new.sanitizedDecimal
                if s != new { text.wrappedValue = s }
            }
    }

    private func karatPicker(_ title: LocalizedStringKey) -> some View {
        Picker(title, selection: $karat) {
            ForEach(Zakat.karats, id: \.self) { Text("\($0)K") }
        }
    }
}

#Preview {
    NavigationStack { GoldCalculatorView() }
        .modelContainer(for: [GoldItem.self], inMemory: true)
}
