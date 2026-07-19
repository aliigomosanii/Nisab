import SwiftUI
import SwiftData

struct GoldItemDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let item: GoldItem
    @AppStorage("goldPrice24kText") private var storedGoldPrice = ""
    @AppStorage("silverPriceText") private var storedSilverPrice = ""
    @AppStorage("goldPriceCurrency") private var priceCurrency = "SAR"
    @State private var confirmDelete = false
    @State private var showingEdit = false
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
                if !item.sellerName.isEmpty {
                    LabeledContent("Seller", value: item.sellerName)
                }
                LabeledContent("Purchase Date", value: item.purchaseDate.dualCalendarString)
                LabeledContent("Purchase Price", value: item.purchasePrice.formatted(.currency(code: item.currencyCode)))
                if let charge = item.manufacturingCharge {
                    LabeledContent("Manufacturing charge", value: charge.formatted(.currency(code: item.currencyCode)))
                }
                if let metalPrice = item.purchaseMetalPricePerGram {
                    if item.material == .silver {
                        LabeledContent("Silver price at purchase (per gram)", value: metalPrice.formatted(.currency(code: item.currencyCode)))
                    } else {
                        LabeledContent("Gold price at purchase (24k, per gram)", value: metalPrice.formatted(.currency(code: item.currencyCode)))
                    }
                }
                if let expected = item.expectedSellingPrice(
                    goldPricePerGram24k: Decimal(string: storedGoldPrice),
                    silverPricePerGram: Decimal(string: storedSilverPrice)
                ) {
                    LabeledContent("Expected selling price") {
                        Text(expected.formatted(.currency(code: priceCurrency)))
                            .bold()
                            .foregroundStyle(Color.accentColor)
                    }
                }
                if let note = item.note, !note.isEmpty {
                    LabeledContent("Note", value: note)
                }
            }


            // Older items can be backfilled through the Edit form.
            if item.purchaseMetalPricePerGram == nil {
                Section {
                    Button("Add metal price at purchase") { showingEdit = true }
                    Text("Used to split selling losses into manufacturing and market change.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
