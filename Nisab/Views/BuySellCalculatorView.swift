import SwiftUI
import SwiftData

private enum TradeMode: String, CaseIterable, Identifiable {
    case buying, selling
    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .buying: "Buying"
        case .selling: "Selling"
        }
    }
}

/// Estimates jewelry prices: buying (gold price + manufacturing charge)
/// and selling (gold/silver content value, importable from the wallet).
struct BuySellCalculatorView: View {
    @Query(sort: \GoldItem.purchaseDate, order: .reverse) private var items: [GoldItem]

    @State private var mode: TradeMode = .buying

    // Buying
    @State private var buyWeightText = ""
    @State private var buyKarat = 21
    @State private var chargeText = ""

    // Selling
    @State private var sellWeightText = ""
    @State private var sellKarat = 21
    @State private var selectedIDs: Set<UUID> = []
    @State private var walletListExpanded = false

    @AppStorage("goldPrice24kText") private var priceText = ""
    @AppStorage("silverPriceText") private var silverPriceText = ""
    @AppStorage("goldPriceCurrency") private var currencyCode = "SAR"

    private var goldPrice: Decimal? { Decimal(string: priceText) }
    private var silverPrice: Decimal? { Decimal(string: silverPriceText) }

    // MARK: - Buying

    private var buyWeight: Decimal { Decimal(string: buyWeightText) ?? 0 }
    private var charge: Decimal { Decimal(string: chargeText) ?? 0 }

    private var buyGoldValue: Decimal? {
        guard buyWeight > 0 else { return nil }
        return goldPrice.map { buyWeight * $0 * Decimal(buyKarat) / 24 }
    }
    private var manufacturingTotal: Decimal { buyWeight * charge }
    private var buyTotal: Decimal? {
        buyGoldValue.map { $0 + manufacturingTotal }
    }

    // MARK: - Selling

    private var selectedItems: [GoldItem] { items.filter { selectedIDs.contains($0.id) } }
    private var sellManualPure: Decimal {
        (Decimal(string: sellWeightText) ?? 0) * Decimal(sellKarat) / 24
    }
    private var sellGoldPure: Decimal {
        sellManualPure + selectedItems.reduce(0) { $0 + $1.pureGoldGrams }
    }
    private var sellSilverGrams: Decimal {
        selectedItems.reduce(0) { $0 + $1.silverGrams }
    }
    private var sellGoldValue: Decimal? {
        guard sellGoldPure > 0 else { return nil }
        return goldPrice.map { sellGoldPure * $0 }
    }
    private var sellSilverValue: Decimal? {
        guard sellSilverGrams > 0 else { return nil }
        return silverPrice.map { sellSilverGrams * $0 }
    }
    private var sellTotal: Decimal? {
        switch (sellGoldValue, sellSilverValue) {
        case (nil, nil): nil
        case let (gold?, nil): gold
        case let (nil, silver?): silver
        case let (gold?, silver?): gold + silver
        }
    }

    private var silverRelevant: Bool {
        mode == .selling && selectedItems.contains { $0.material == .silver }
    }

    // MARK: - Approximate loss (wallet items only — they carry a purchase price)

    private var selectedPurchaseTotal: Decimal {
        selectedItems.reduce(0) { $0 + $1.purchasePrice }
    }

    /// Sale value of just the selected wallet items; nil while a needed
    /// price is missing.
    private var selectedSaleValue: Decimal? {
        let goldPure = selectedItems.reduce(0) { $0 + $1.pureGoldGrams }
        let silver = selectedItems.reduce(0) { $0 + $1.silverGrams }
        guard goldPure > 0 || silver > 0 else { return nil }
        var total: Decimal = 0
        if goldPure > 0 {
            guard let goldPrice else { return nil }
            total += goldPure * goldPrice
        }
        if silver > 0 {
            guard let silverPrice else { return nil }
            total += silver * silverPrice
        }
        return total
    }

    /// Positive = loss versus purchase price, negative = gain.
    private var approximateLoss: Decimal? {
        guard let selectedSaleValue else { return nil }
        return selectedPurchaseTotal - selectedSaleValue
    }

    var body: some View {
        Form {
            Section {
                Picker("Mode", selection: $mode) {
                    ForEach(TradeMode.allCases) { m in
                        Text(m.title).tag(m)
                    }
                }
                .pickerStyle(.segmented)
            }

            if mode == .buying {
                Section("Gold") {
                    decimalField("Weight (grams)", text: $buyWeightText)
                    karatPicker("Karat", selection: $buyKarat)
                    decimalField("Manufacturing charge / gram", text: $chargeText)
                }

                GoldPriceSection()

                if let buyGoldValue, let buyTotal {
                    Section("Result") {
                        LabeledContent("Gold value", value: buyGoldValue.formatted(.currency(code: currencyCode)))
                        LabeledContent("Manufacturing total", value: manufacturingTotal.formatted(.currency(code: currencyCode)))
                        LabeledContent("Total price") {
                            Text(buyTotal.formatted(.currency(code: currencyCode)))
                                .bold()
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            } else {
                Section("Gold") {
                    decimalField("Weight (grams)", text: $sellWeightText)
                    karatPicker("Karat", selection: $sellKarat)
                }

                if !items.isEmpty {
                    Section {
                        DisclosureGroup(isExpanded: $walletListExpanded) {
                            walletRows
                        } label: {
                            Text("Add from Jewelry Wallet")
                        }
                    }
                }

                GoldPriceSection(includeSilver: silverRelevant)

                if sellGoldPure > 0 || sellSilverGrams > 0 {
                    Section("Result") {
                        if sellGoldPure > 0, let sellGoldValue {
                            LabeledContent("Gold value", value: sellGoldValue.formatted(.currency(code: currencyCode)))
                        }
                        if sellSilverGrams > 0 {
                            LabeledContent("Total silver") {
                                Text("\(sellSilverGrams.formatted(.number.precision(.fractionLength(0...2)))) g")
                            }
                            if let sellSilverValue {
                                LabeledContent("Silver value", value: sellSilverValue.formatted(.currency(code: currencyCode)))
                            }
                        }
                        if let sellTotal {
                            LabeledContent("Estimated sale value") {
                                Text(sellTotal.formatted(.currency(code: currencyCode)))
                                    .bold()
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        if let approximateLoss {
                            LabeledContent("Total purchase price", value: selectedPurchaseTotal.formatted(.currency(code: currencyCode)))
                            if approximateLoss >= 0 {
                                LabeledContent("Manufacturing loss") {
                                    Text(approximateLoss.formatted(.currency(code: currencyCode)))
                                        .bold()
                                        .foregroundStyle(.red)
                                }
                            } else {
                                LabeledContent("Approximate gain") {
                                    Text((-approximateLoss).formatted(.currency(code: currencyCode)))
                                        .bold()
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }

                    Section {
                        Text("Sale estimates are based on metal content at today's price; shops may pay less and manufacturing charges are not recovered.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if approximateLoss != nil {
                            Text("The loss is roughly the manufacturing charge and wear compared with the metal value at today's price.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Pieces

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

    private func decimalField(_ title: LocalizedStringKey, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .keyboardType(.decimalPad)
            .onChange(of: text.wrappedValue) { _, new in
                let s = new.sanitizedDecimal
                if s != new { text.wrappedValue = s }
            }
    }

    private func karatPicker(_ title: LocalizedStringKey, selection: Binding<Int>) -> some View {
        Picker(title, selection: selection) {
            ForEach(Zakat.karats, id: \.self) { Text("\($0)K") }
        }
    }
}

#Preview {
    NavigationStack { BuySellCalculatorView() }
        .modelContainer(for: [GoldItem.self], inMemory: true)
}
