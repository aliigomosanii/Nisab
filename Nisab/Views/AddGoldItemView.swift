import SwiftUI
import SwiftData
import PhotosUI
import PDFKit

/// Which photo slot a picker is feeding.
private enum PhotoTarget: String, Identifiable {
    case item, invoice
    var id: String { rawValue }
}

struct AddGoldItemView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// When set, the form edits this item instead of creating a new one.
    var editingItem: GoldItem?

    @State private var material: JewelryMaterial = .gold
    @State private var name = ""
    /// Gold/silver weight in grams; for diamond items, the gold setting weight.
    @State private var weightText = ""
    @State private var karat = 24
    @State private var sellerName = ""
    @State private var purchaseDate = Date.now
    @State private var priceText = ""
    @State private var manufacturingChargeText = ""
    @State private var purchaseMetalPriceText = ""
    @State private var currencyCode = "SAR"
    @State private var note = ""
    @State private var itemPickerItem: PhotosPickerItem?
    @State private var itemData: Data?
    @State private var itemImage: UIImage?
    @State private var invoicePickerItem: PhotosPickerItem?
    @State private var invoiceData: Data?
    @State private var invoiceImage: UIImage?
    @State private var showItemLibrary = false
    @State private var showInvoiceLibrary = false
    @State private var cameraTarget: PhotoTarget?
    @State private var fileTarget: PhotoTarget?
    @State private var showFileImporter = false

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
                    TextField("Seller", text: $sellerName)
                    decimalField("Purchase Price", text: $priceText)
                    decimalField("Manufacturing charge", text: $manufacturingChargeText)
                    decimalField(
                        material == .silver
                            ? "Silver price at purchase (per gram)"
                            : "Gold price at purchase (24k, per gram)",
                        text: $purchaseMetalPriceText
                    )
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(Self.currencies, id: \.self) { Text($0) }
                    }
                }

                photoSection(
                    title: "Item Photo",
                    addLabel: "Add Item Photo",
                    icon: "photo",
                    target: .item,
                    data: $itemData,
                    image: $itemImage
                )
                photoSection(
                    title: "Invoice",
                    addLabel: "Add Invoice Photo",
                    icon: "doc.text.image",
                    target: .invoice,
                    data: $invoiceData,
                    image: $invoiceImage
                )

                Section("Note") {
                    TextField("Note", text: $note, axis: .vertical)
                }
            }
            .navigationTitle(editingItem == nil ? "Add Jewelry Item" : "Edit Jewelry Item")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let item = editingItem {
                    material = item.material
                    name = item.name
                    sellerName = item.sellerName
                    if let charge = item.manufacturingCharge {
                        manufacturingChargeText = "\(charge)"
                    }
                    weightText = "\(item.weightGrams)"
                    karat = item.karat
                    purchaseDate = item.purchaseDate
                    priceText = "\(item.purchasePrice)"
                    if let metalPrice = item.purchaseMetalPricePerGram {
                        purchaseMetalPriceText = "\(metalPrice)"
                    }
                    currencyCode = item.currencyCode
                    note = item.note ?? ""
                    // Downsample once here: caps decode cost while editing and
                    // shrinks oversized legacy photos on the next save.
                    (itemData, itemImage) = Self.processed(item.itemImageData)
                    (invoiceData, invoiceImage) = Self.processed(item.invoiceImageData)
                } else {
                    karat = UserDefaults.standard.object(forKey: "defaultKarat") as? Int ?? 24
                    currencyCode = UserDefaults.standard.string(forKey: "goldPriceCurrency") ?? "SAR"
                }
            }
            .onChange(of: itemPickerItem) { _, pickerItem in
                Task {
                    let raw = try? await pickerItem?.loadTransferable(type: Data.self)
                    if raw != nil { (itemData, itemImage) = Self.processed(raw) }
                }
            }
            .onChange(of: invoicePickerItem) { _, pickerItem in
                Task {
                    let raw = try? await pickerItem?.loadTransferable(type: Data.self)
                    if raw != nil { (invoiceData, invoiceImage) = Self.processed(raw) }
                }
            }
            .photosPicker(isPresented: $showItemLibrary, selection: $itemPickerItem, matching: .images)
            .photosPicker(isPresented: $showInvoiceLibrary, selection: $invoicePickerItem, matching: .images)
            .fullScreenCover(item: $cameraTarget) { target in
                CameraPicker { image in
                    apply(Self.processed(image: image), to: target)
                }
                .ignoresSafeArea()
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf, .image]) { result in
                handleImportedFile(result)
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

    /// Decodes once and caps resolution so form re-renders stay cheap.
    private static func processed(_ raw: Data?) -> (Data?, UIImage?) {
        guard let raw, let original = UIImage(data: raw) else { return (nil, nil) }
        return processed(image: original, originalData: raw)
    }

    private static func processed(image original: UIImage, originalData: Data? = nil) -> (Data?, UIImage?) {
        let maxDimension: CGFloat = 1600
        let largest = max(original.size.width, original.size.height)
        if largest <= maxDimension, let originalData {
            return (originalData, original)
        }
        let scale = min(1, maxDimension / largest)
        let target = CGSize(width: original.size.width * scale, height: original.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: target).image { _ in
            original.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let jpeg = resized.jpegData(compressionQuality: 0.8) else { return (originalData, original) }
        return (jpeg, resized)
    }

    /// First page of a PDF rendered as an image.
    private static func pdfFirstPageImage(_ data: Data) -> UIImage? {
        guard let document = PDFDocument(data: data), let page = document.page(at: 0) else {
            return nil
        }
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
    }

    private func apply(_ processed: (Data?, UIImage?), to target: PhotoTarget) {
        switch target {
        case .item: (itemData, itemImage) = processed
        case .invoice: (invoiceData, invoiceImage) = processed
        }
    }

    private func handleImportedFile(_ result: Result<URL, Error>) {
        guard let target = fileTarget, case .success(let url) = result else {
            fileTarget = nil
            return
        }
        defer { fileTarget = nil }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let raw = try? Data(contentsOf: url) else { return }
        let image: UIImage? = url.pathExtension.lowercased() == "pdf"
            ? Self.pdfFirstPageImage(raw)
            : UIImage(data: raw)
        guard let image else { return }
        apply(Self.processed(image: image), to: target)
    }

    private func photoSection(
        title: LocalizedStringKey,
        addLabel: LocalizedStringKey,
        icon: String,
        target: PhotoTarget,
        data: Binding<Data?>,
        image: Binding<UIImage?>
    ) -> some View {
        Section(title) {
            Menu {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        cameraTarget = target
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                    }
                }
                Button {
                    if target == .item { showItemLibrary = true } else { showInvoiceLibrary = true }
                } label: {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                }
                Button {
                    fileTarget = target
                    showFileImporter = true
                } label: {
                    Label("Choose File (photo or PDF)", systemImage: "folder")
                }
            } label: {
                Label(addLabel, systemImage: icon)
            }
            if let uiImage = image.wrappedValue {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Button("Remove Photo", role: .destructive) {
                    data.wrappedValue = nil
                    image.wrappedValue = nil
                }
            }
        }
    }

    private func save() {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let item = editingItem {
            item.name = name.trimmingCharacters(in: .whitespaces)
            item.sellerName = sellerName.trimmingCharacters(in: .whitespaces)
            item.manufacturingCharge = Decimal(string: manufacturingChargeText)
            item.material = material
            item.weightGrams = weight ?? 0
            item.karat = karat
            item.purchaseDate = purchaseDate
            item.purchasePrice = price ?? 0
            item.purchaseMetalPricePerGram = Decimal(string: purchaseMetalPriceText)
            item.currencyCode = currencyCode
            item.invoiceImageData = invoiceData
            item.itemImageData = itemData
            item.note = trimmedNote.isEmpty ? nil : trimmedNote
        } else {
            let item = GoldItem(
                name: name.trimmingCharacters(in: .whitespaces),
                material: material,
                weightGrams: weight ?? 0,
                karat: karat,
                sellerName: sellerName.trimmingCharacters(in: .whitespaces),
                manufacturingCharge: Decimal(string: manufacturingChargeText),
                purchaseDate: purchaseDate,
                purchasePrice: price ?? 0,
                purchaseMetalPricePerGram: Decimal(string: purchaseMetalPriceText),
                currencyCode: currencyCode,
                invoiceImageData: invoiceData,
                itemImageData: itemData,
                note: trimmedNote.isEmpty ? nil : trimmedNote
            )
            context.insert(item)
        }
        dismiss()
    }
}

#Preview {
    AddGoldItemView()
        .modelContainer(for: [GoldItem.self], inMemory: true)
}
