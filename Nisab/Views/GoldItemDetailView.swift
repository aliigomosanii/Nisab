import SwiftUI
import SwiftData

struct GoldItemDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let item: GoldItem
    @State private var confirmDelete = false
    @State private var showingEdit = false
    @State private var purchaseMetalPriceText = ""
    // Decoded once (and again after edits) so typing doesn't re-decode photos.
    @State private var itemImage: UIImage?
    @State private var invoiceImage: UIImage?
    @State private var certificateImage: UIImage?

    private func reloadImages() {
        itemImage = item.itemImageData.flatMap(UIImage.init(data:))
        invoiceImage = item.invoiceImageData.flatMap(UIImage.init(data:))
        certificateImage = item.certificateImageData.flatMap(UIImage.init(data:))
    }

    private var materialTitle: String {
        switch item.material {
        case .gold: String(localized: "Gold", bundle: L10n.bundle)
        case .silver: String(localized: "Silver", bundle: L10n.bundle)
        case .diamond: String(localized: "Diamond", bundle: L10n.bundle)
        }
    }

    var body: some View {
        List {
            Section("Details") {
                if !item.name.isEmpty {
                    LabeledContent("Name", value: item.name)
                }
                LabeledContent("Material") { Text(item.material.title) }
                switch item.material {
                case .gold:
                    LabeledContent("Weight (grams)") {
                        Text("\(item.weightGrams.formatted(.number.precision(.fractionLength(0...2)))) g")
                    }
                    LabeledContent("Karat", value: "\(item.karat)K")
                case .silver:
                    LabeledContent("Weight (grams)") {
                        Text("\(item.weightGrams.formatted(.number.precision(.fractionLength(0...2)))) g")
                    }
                case .diamond:
                    LabeledContent("Diamond Carat (ct)") {
                        Text((item.diamondCarat ?? 0).formatted(.number.precision(.fractionLength(0...2))))
                    }
                    LabeledContent("Gold Weight (grams)") {
                        Text("\(item.weightGrams.formatted(.number.precision(.fractionLength(0...2)))) g")
                    }
                    LabeledContent("Gold Karat", value: "\(item.karat)K")
                }
                if item.material != .silver {
                    LabeledContent("Pure gold equivalent") {
                        Text("\(item.pureGoldGrams.formatted(.number.precision(.fractionLength(0...2)))) g")
                    }
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


            // Editable so older items can be backfilled for selling estimates.
            Section {
                TextField(
                    item.material == .silver
                        ? "Silver price at purchase (per gram)"
                        : "Gold price at purchase (24k, per gram)",
                    text: $purchaseMetalPriceText
                )
                .keyboardType(.decimalPad)
                .onChange(of: purchaseMetalPriceText) { _, new in
                    let s = new.sanitizedDecimal
                    if s != new {
                        purchaseMetalPriceText = s
                    } else {
                        item.purchaseMetalPricePerGram = Decimal(string: s)
                    }
                }
                Text("Used to split selling losses into manufacturing and market change.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .onAppear {
                if let price = item.purchaseMetalPricePerGram {
                    purchaseMetalPriceText = "\(price)"
                }
            }

            if let itemImage {
                Section("Item Photo") {
                    Image(uiImage: itemImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            if let invoiceImage {
                Section("Invoice") {
                    Image(uiImage: invoiceImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            if let certificateImage {
                Section("Certificate") {
                    Image(uiImage: certificateImage)
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
        .navigationTitle(item.name.isEmpty ? materialTitle : item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            AddGoldItemView(editingItem: item)
        }
        .onAppear { reloadImages() }
        .onChange(of: item.itemImageData) { _, _ in reloadImages() }
        .onChange(of: item.invoiceImageData) { _, _ in reloadImages() }
        .onChange(of: item.certificateImageData) { _, _ in reloadImages() }
        .confirmationDialog("Delete this record?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                context.delete(item)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
