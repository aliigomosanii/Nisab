import SwiftUI
import SwiftData
import PhotosUI

struct AddGoldItemView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var material: JewelryMaterial = .gold
    @State private var name = ""
    /// Gold/silver weight in grams; for diamond items, the gold setting weight.
    @State private var weightText = ""
    @State private var karat = 24
    @State private var purchaseDate = Date.now
    @State private var priceText = ""
    @State private var currencyCode = "SAR"
    @State private var note = ""
    @State private var itemPickerItem: PhotosPickerItem?
    @State private var itemData: Data?
    @State private var invoicePickerItem: PhotosPickerItem?
    @State private var invoiceData: Data?

    private static let currencies = ["SAR", "USD", "AED", "PKR", "INR", "EGP", "EUR"]

    private var weight: Decimal? { Decimal(string: weightText) }
    private var price: Decimal? { Decimal(string: priceText) }

    private var canSave: Bool {
        (price ?? 0) > 0 && (weight ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
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
                    TextField("Name", text: $name)
                    weightField("Weight (grams)")
                    if material == .gold {
                        karatPicker("Karat")
                    }
                }

                Section("Purchase Date") {
                    DatePicker("Purchase Date", selection: $purchaseDate, in: ...Date.now, displayedComponents: .date)
                    Text(purchaseDate.dualCalendarString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Purchase Price") {
                    decimalField("Purchase Price", text: $priceText)
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(Self.currencies, id: \.self) { Text($0) }
                    }
                }

                photoSection(
                    title: "Item Photo",
                    addLabel: "Add Item Photo",
                    icon: "photo",
                    pickerItem: $itemPickerItem,
                    data: $itemData
                )
                photoSection(
                    title: "Invoice",
                    addLabel: "Add Invoice Photo",
                    icon: "doc.text.image",
                    pickerItem: $invoicePickerItem,
                    data: $invoiceData
                )

                Section("Note") {
                    TextField("Note", text: $note, axis: .vertical)
                }
            }
            .navigationTitle("Add Jewelry Item")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                karat = UserDefaults.standard.object(forKey: "defaultKarat") as? Int ?? 24
                currencyCode = UserDefaults.standard.string(forKey: "goldPriceCurrency") ?? "SAR"
            }
            .onChange(of: itemPickerItem) { _, item in
                Task { itemData = try? await item?.loadTransferable(type: Data.self) }
            }
            .onChange(of: invoicePickerItem) { _, item in
                Task { invoiceData = try? await item?.loadTransferable(type: Data.self) }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    // MARK: - Field helpers

    private func decimalField(_ title: LocalizedStringKey, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .keyboardType(.decimalPad)
            .onChange(of: text.wrappedValue) { _, new in
                let s = new.sanitizedDecimal
                if s != new { text.wrappedValue = s }
            }
    }

    private func weightField(_ title: LocalizedStringKey) -> some View {
        decimalField(title, text: $weightText)
    }

    private func karatPicker(_ title: LocalizedStringKey) -> some View {
        Picker(title, selection: $karat) {
            ForEach(Zakat.karats, id: \.self) { Text("\($0)K") }
        }
    }

    private func photoSection(
        title: LocalizedStringKey,
        addLabel: LocalizedStringKey,
        icon: String,
        pickerItem: Binding<PhotosPickerItem?>,
        data: Binding<Data?>
    ) -> some View {
        Section(title) {
            PhotosPicker(selection: pickerItem, matching: .images) {
                Label(addLabel, systemImage: icon)
            }
            if let imageData = data.wrappedValue, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Button("Remove Photo", role: .destructive) {
                    data.wrappedValue = nil
                    pickerItem.wrappedValue = nil
                }
            }
        }
    }

    private func save() {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = GoldItem(
            name: name.trimmingCharacters(in: .whitespaces),
            material: material,
            weightGrams: weight ?? 0,
            karat: karat,
            purchaseDate: purchaseDate,
            purchasePrice: price ?? 0,
            currencyCode: currencyCode,
            invoiceImageData: invoiceData,
            itemImageData: itemData,
            note: trimmedNote.isEmpty ? nil : trimmedNote
        )
        context.insert(item)
        dismiss()
    }
}

#Preview {
    AddGoldItemView()
        .modelContainer(for: [GoldItem.self], inMemory: true)
}
