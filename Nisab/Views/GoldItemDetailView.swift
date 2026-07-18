import SwiftUI
import SwiftData

struct GoldItemDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let item: GoldItem
    @State private var confirmDelete = false

    var body: some View {
        List {
            Section("Details") {
                if !item.name.isEmpty {
                    LabeledContent("Name", value: item.name)
                }
                LabeledContent("Weight (grams)") {
                    Text("\(item.weightGrams.formatted(.number.precision(.fractionLength(0...2)))) g")
                }
                LabeledContent("Karat", value: "\(item.karat)K")
                LabeledContent("Pure gold equivalent") {
                    Text("\(item.pureGoldGrams.formatted(.number.precision(.fractionLength(0...2)))) g")
                }
                LabeledContent("Purchase Date", value: item.purchaseDate.dualCalendarString)
                LabeledContent("Purchase Price", value: item.purchasePrice.formatted(.currency(code: item.currencyCode)))
                if let note = item.note, !note.isEmpty {
                    LabeledContent("Note", value: note)
                }
            }

            Section("Zakat Payments") {
                LabeledContent("Next payment") {
                    if let next = item.nextZakatDue {
                        Text(next.dualCalendarString)
                            .foregroundStyle(item.isZakatExempt ? .green : .primary)
                            .multilineTextAlignment(.trailing)
                    } else {
                        Text("Due now")
                            .foregroundStyle(.orange)
                            .bold()
                    }
                }
                if item.paymentHistory.isEmpty {
                    Text("No payments yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(item.paymentHistory, id: \.self) { date in
                        Label {
                            Text(date.dualCalendarString)
                        } icon: {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }

            if item.isZakatExempt {
                Section {
                    Button("Remove Zakat Payment", role: .destructive) {
                        if let last = item.lastZakatPaidAt {
                            item.zakatPaymentDates.removeAll { $0 == last }
                        }
                        item.lastZakatPaidAt = item.zakatPaymentDates.max()
                    }
                }
            }

            if let data = item.invoiceImageData, let image = UIImage(data: data) {
                Section("Invoice") {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Section {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .navigationTitle(item.name.isEmpty ? String(localized: "Gold", bundle: L10n.bundle) : item.name)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this record?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                context.delete(item)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
