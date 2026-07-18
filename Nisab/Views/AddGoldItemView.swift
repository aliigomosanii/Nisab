import SwiftUI
import SwiftData
import PhotosUI

struct AddGoldItemView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var weightText = ""
    @State private var karat = 24
    @State private var purchaseDate = Date.now
    @State private var priceText = ""
    @State private var currencyCode = "SAR"
    @State private var note = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var invoiceData: Data?

    private static let currencies = ["SAR", "USD", "AED", "PKR", "INR", "EGP", "EUR"]

    private var weight: Decimal? { Decimal(string: weightText) }
    private var price: Decimal? { Decimal(string: priceText) }

    private var canSave: Bool {
        (weight ?? 0) > 0 && (price ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Gold") {
                    TextField("Name", text: $name)
                    TextField("Weight (grams)", text: $weightText)
                        .keyboardType(.decimalPad)
                        .onChange(of: weightText) { _, new in
                            let s = new.sanitizedDecimal
                            if s != new { weightText = s }
                        }
                    Picker("Karat", selection: $karat) {
                        ForEach(Zakat.karats, id: \.self) { Text("\($0)K") }
                    }
                }

                Section("Purchase Date") {
                    DatePicker("Purchase Date", selection: $purchaseDate, in: ...Date.now, displayedComponents: .date)
                    Text(purchaseDate.dualCalendarString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Purchase Price") {
                    TextField("Purchase Price", text: $priceText)
                        .keyboardType(.decimalPad)
                        .onChange(of: priceText) { _, new in
                            let s = new.sanitizedDecimal
                            if s != new { priceText = s }
                        }
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(Self.currencies, id: \.self) { Text($0) }
                    }
                }

                Section("Invoice") {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Add Invoice Photo", systemImage: "doc.text.image")
                    }
                    if let invoiceData, let image = UIImage(data: invoiceData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Button("Remove Invoice", role: .destructive) {
                            self.invoiceData = nil
                            pickerItem = nil
                        }
                    }
                }

                Section("Note") {
                    TextField("Note", text: $note, axis: .vertical)
                }
            }
            .navigationTitle("Add Gold Item")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: pickerItem) { _, item in
                Task {
                    invoiceData = try? await item?.loadTransferable(type: Data.self)
                }
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

    private func save() {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = GoldItem(
            name: name.trimmingCharacters(in: .whitespaces),
            weightGrams: weight ?? 0,
            karat: karat,
            purchaseDate: purchaseDate,
            purchasePrice: price ?? 0,
            currencyCode: currencyCode,
            invoiceImageData: invoiceData,
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
