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

    /// Typical Saudi manufacturing charge guidance per karat (SAR/gram),
    /// from local market reference data.
    private var chargeHintKey: LocalizedStringKey {
        switch buyKarat {
        case 24: "Typical for 24K (bars, liras): 0–5 SAR/g, up to 10 for small bars."
        case 22: "Typical for 22K (Gulf and traditional jewelry): 5–12 SAR/g."
        case 21: "Typical for 21K (most common in Saudi): 10–20 SAR/g; 30–60+ for luxury designs and brands."
        default: "Typical for 18K (modern jewelry and brands): 20–80+ SAR/g depending on design and brand."
        }
    }

    private var chargeSuggestions: [Int] {
        switch buyKarat {
        case 24: [3, 5, 10]
        case 22: [5, 8, 12]
        case 21: [10, 15, 20]
        default: [20, 40, 80]
        }
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

    /// Metal value on the purchase day — only when every selected item
    /// recorded its purchase-day metal price.
    private var metalValueAtPurchase: Decimal? {
        guard !selectedItems.isEmpty,
              selectedItems.allSatisfy({ $0.purchaseMetalPricePerGram != nil }) else {
            return nil
        }
        return selectedItems.reduce(0) { sum, item in
            let grams = item.material == .silver ? item.silverGrams : item.pureGoldGrams
            return sum + grams * (item.purchaseMetalPricePerGram ?? 0)
        }
    }

    /// What was paid above the metal value at purchase: manufacturing,
    /// VAT, and brand markup.
    private var manufacturingComponent: Decimal? {
        metalValueAtPurchase.map { selectedPurchaseTotal - $0 }
    }

    /// Positive = the metal price dropped since purchase.
    private var marketChange: Decimal? {
        guard let metalValueAtPurchase, let selectedSaleValue else { return nil }
        return metalValueAtPurchase - selectedSaleValue
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
                    // Saudi market reference ranges (figures in SAR).
                    if currencyCode == "SAR" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(chargeHintKey)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                ForEach(chargeSuggestions, id: \.self) { value in
                                    Button("\(value)") {
                                        chargeText = "\(value)"
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }
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
                        if selectedItems.isEmpty {
                            Text("Select items from your wallet to see the manufacturing loss versus their purchase price.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                            if let manufacturingComponent, let marketChange {
                                LabeledContent("Manufacturing & markup") {
                                    Text(manufacturingComponent.formatted(.currency(code: currencyCode)))
                                        .foregroundStyle(manufacturingComponent > 0 ? .red : .secondary)
                                }
                                LabeledContent("Market change") {
                                    // Shown from the seller's view: ▼ red =
                                    // the metal price fell since purchase.
                                    HStack(spacing: 4) {
                                        if marketChange != 0 {
                                            Image(systemName: marketChange > 0 ? "arrow.down" : "arrow.up")
                                                .font(.caption2.bold())
                                        }
                                        Text((-marketChange).formatted(.currency(code: currencyCode)))
                                    }
                                    .foregroundStyle(marketChange > 0 ? .red : (marketChange < 0 ? .green : .secondary))
                                }
                            }
                            if approximateLoss >= 0 {
                                LabeledContent("Loss vs. metal value") {
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
                            if manufacturingComponent != nil {
                                Text("Manufacturing & markup includes making charges, VAT, and any brand margin paid at purchase.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Add the metal price at purchase on each item to split this loss into manufacturing and market change.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
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
