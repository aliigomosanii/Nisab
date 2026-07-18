import SwiftUI
import SwiftData

/// Records a zakat payment for selected gold items, exempting them
/// from zakat until one Hijri year after the payment date.
struct PayZakatView: View {
    @Environment(\.dismiss) private var dismiss

    /// Items eligible for payment (not currently exempt).
    let items: [GoldItem]

    @State private var selectedIDs: Set<UUID>
    @State private var paymentDate = Date.now
    @AppStorage("goldPrice24kText") private var priceText = ""
    @AppStorage("goldPriceCurrency") private var currencyCode = "SAR"

    init(items: [GoldItem]) {
        self.items = items
        _selectedIDs = State(initialValue: Set(items.map(\.id)))
    }

    private var selectedItems: [GoldItem] {
        items.filter { selectedIDs.contains($0.id) }
    }

    private var selectedPureGrams: Decimal {
        selectedItems.reduce(0) { $0 + $1.pureGoldGrams }
    }

    private var zakatGrams: Decimal { selectedPureGrams * Zakat.rate }

    /// Zakat is only due (and thus recordable) at or above nisab.
    private var aboveNisab: Bool { selectedPureGrams >= Zakat.nisabGrams }

    private var zakatValue: Decimal? {
        Decimal(string: priceText).map { selectedPureGrams * $0 * Zakat.rate }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Gold") {
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
                                    Text(item.name.isEmpty
                                         ? "\(item.weightGrams.formatted(.number.precision(.fractionLength(0...2)))) g · \(item.karat)K"
                                         : item.name)
                                        .foregroundStyle(.primary)
                                    if !item.name.isEmpty {
                                        Text("\(item.weightGrams.formatted(.number.precision(.fractionLength(0...2)))) g · \(item.karat)K")
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

                Section("Payment Date") {
                    DatePicker("Payment Date", selection: $paymentDate, in: ...Date.now, displayedComponents: .date)
                    Text(paymentDate.dualCalendarString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !selectedItems.isEmpty {
                    Section("Result") {
                        LabeledContent("Pure gold equivalent") {
                            Text("\(selectedPureGrams.formatted(.number.precision(.fractionLength(0...2)))) g")
                        }
                        LabeledContent("Nisab (85g pure gold)") {
                            Text(aboveNisab ? "Above nisab" : "Below nisab")
                                .foregroundStyle(aboveNisab ? Color.green : .red)
                        }
                        LabeledContent("Zakat due (2.5%)") {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(zakatGrams.formatted(.number.precision(.fractionLength(0...2)))) g")
                                    .bold()
                                if let zakatValue {
                                    Text(zakatValue.formatted(.currency(code: currencyCode)))
                                        .bold()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Record Zakat Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!aboveNisab)
                }
            }
        }
    }

    private func save() {
        for item in selectedItems {
            item.lastZakatPaidAt = paymentDate
            item.zakatPaymentDates.append(paymentDate)
        }
        dismiss()
    }
}
