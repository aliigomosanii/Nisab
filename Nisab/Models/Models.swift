import Foundation
import SwiftData
import SwiftUI

/// Kind of jewelry tracked in the wallet.
enum JewelryMaterial: String, CaseIterable, Identifiable {
    case gold, silver, diamond
    var id: String { rawValue }

    /// Materials offered in the UI (diamond kept in the enum only for
    /// compatibility with previously saved items).
    static let selectable: [JewelryMaterial] = [.gold, .silver]

    var title: LocalizedStringKey {
        switch self {
        case .gold: "Gold"
        case .silver: "Silver"
        case .diamond: "Diamond"
        }
    }
}

/// A piece of jewelry tracked in the Jewelry Wallet for zakat.
/// (Class name kept as GoldItem for SwiftData store compatibility.)
@Model
final class GoldItem {
    @Attribute(.unique) var id: UUID
    /// Optional label, e.g. "Wedding ring".
    var name: String = ""
    private var materialRaw: String = "gold"
    /// Gold/silver weight in grams. For diamond items this is the weight
    /// of the gold setting.
    var weightGrams: Decimal
    /// Gold purity in karat (24 = pure). Unused for silver.
    var karat: Int
    /// Diamond stone weight in carats (diamond items only).
    var diamondCarat: Decimal?
    var purchaseDate: Date
    var purchasePrice: Decimal
    /// Pure-metal price per gram on the purchase day (24k for gold items,
    /// silver spot for silver). Lets selling estimates split the loss into
    /// manufacturing/markup vs. market movement.
    var purchaseMetalPricePerGram: Decimal?
    var currencyCode: String
    /// Invoice photo; stored outside the database file.
    @Attribute(.externalStorage) var invoiceImageData: Data?
    /// Certificate photo (diamond items), stored outside the database file.
    @Attribute(.externalStorage) var certificateImageData: Data?
    /// Photo of the item itself; stored outside the database file.
    @Attribute(.externalStorage) var itemImageData: Data?
    var note: String?
    var createdAt: Date
    /// When zakat was last paid on this item; exempts it for one Hijri year.
    var lastZakatPaidAt: Date?
    /// Full history of zakat payments recorded for this item.
    var zakatPaymentDates: [Date] = []

    var material: JewelryMaterial {
        get { JewelryMaterial(rawValue: materialRaw) ?? .gold }
        set { materialRaw = newValue.rawValue }
    }

    /// Pure (24k-equivalent) gold content in grams. Diamonds themselves are
    /// not zakatable — only the gold setting counts. Silver contributes none.
    var pureGoldGrams: Decimal {
        material == .silver ? 0 : weightGrams * Decimal(karat) / 24
    }

    /// Silver content in grams (silver items only).
    var silverGrams: Decimal {
        material == .silver ? weightGrams : 0
    }

    /// One-line physical description, e.g. "15 g · 21K" or "1.2 ct · 5 g 18K".
    var summaryLine: String {
        let weight = weightGrams.formatted(.number.precision(.fractionLength(0...2)))
        switch material {
        case .gold: return "\(weight) g · \(karat)K"
        case .silver: return "\(weight) g"
        case .diamond:
            let carat = (diamondCarat ?? 0).formatted(.number.precision(.fractionLength(0...2)))
            return "\(carat) ct · \(weight) g \(karat)K"
        }
    }

    /// End of the exemption: the hawl anniversary is anchored to the
    /// purchase date, so this is the next Umm al-Qura lunar-year
    /// anniversary of the purchase date that falls after the payment —
    /// paying late does not shift the following due date.
    var zakatExemptUntil: Date? {
        guard let lastZakatPaidAt else { return nil }
        let calendar = Calendar(identifier: .islamicUmmAlQura)
        var anniversary = purchaseDate
        while anniversary <= lastZakatPaidAt {
            guard let next = calendar.date(byAdding: .year, value: 1, to: anniversary) else {
                return nil
            }
            anniversary = next
        }
        return anniversary
    }

    /// True while the item is inside its paid lunar year.
    var isZakatExempt: Bool {
        guard let zakatExemptUntil else { return false }
        return Date.now < zakatExemptUntil
    }

    /// When the next zakat payment is expected. Nil means zakat is due now
    /// (the first hawl has completed and the item is not exempt).
    var nextZakatDue: Date? {
        if isZakatExempt { return zakatExemptUntil }
        let calendar = Calendar(identifier: .islamicUmmAlQura)
        guard let firstAnniversary = calendar.date(byAdding: .year, value: 1, to: purchaseDate) else {
            return nil
        }
        return Date.now < firstAnniversary ? firstAnniversary : nil
    }

    /// Payment history, newest first, tolerating pre-history records that
    /// only stored lastZakatPaidAt.
    var paymentHistory: [Date] {
        var dates = zakatPaymentDates
        if let lastZakatPaidAt, !dates.contains(lastZakatPaidAt) {
            dates.append(lastZakatPaidAt)
        }
        return dates.sorted(by: >)
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        material: JewelryMaterial = .gold,
        weightGrams: Decimal,
        karat: Int,
        diamondCarat: Decimal? = nil,
        purchaseDate: Date,
        purchasePrice: Decimal,
        purchaseMetalPricePerGram: Decimal? = nil,
        currencyCode: String = "SAR",
        invoiceImageData: Data? = nil,
        certificateImageData: Data? = nil,
        itemImageData: Data? = nil,
        note: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.materialRaw = material.rawValue
        self.weightGrams = weightGrams
        self.karat = karat
        self.diamondCarat = diamondCarat
        self.purchaseDate = purchaseDate
        self.purchasePrice = purchasePrice
        self.purchaseMetalPricePerGram = purchaseMetalPricePerGram
        self.currencyCode = currencyCode
        self.invoiceImageData = invoiceImageData
        self.certificateImageData = certificateImageData
        self.itemImageData = itemImageData
        self.note = note
        self.createdAt = createdAt
    }
}

/// Zakat rules (standard fiqh values).
enum Zakat {
    /// Gold nisab threshold: 85 grams of pure gold.
    static let nisabGrams: Decimal = 85
    /// Silver nisab threshold: 595 grams.
    static let silverNisabGrams: Decimal = 595
    /// Zakat rate: 2.5%.
    static let rate: Decimal = 0.025

    static let karats = [24, 22, 21, 18]
}
