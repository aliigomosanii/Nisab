import Foundation
import SwiftData

/// A piece of owned gold tracked in the Gold Wallet for zakat.
@Model
final class GoldItem {
    @Attribute(.unique) var id: UUID
    /// Optional label, e.g. "Wedding ring".
    var name: String = ""
    var weightGrams: Decimal
    /// Purity in karat (24 = pure).
    var karat: Int
    var purchaseDate: Date
    var purchasePrice: Decimal
    var currencyCode: String
    /// Invoice photo; stored outside the database file.
    @Attribute(.externalStorage) var invoiceImageData: Data?
    var note: String?
    var createdAt: Date
    /// When zakat was last paid on this item; exempts it for one Hijri year.
    var lastZakatPaidAt: Date?
    /// Full history of zakat payments recorded for this item.
    var zakatPaymentDates: [Date] = []

    /// Pure (24k-equivalent) gold content in grams.
    var pureGoldGrams: Decimal {
        weightGrams * Decimal(karat) / 24
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
        weightGrams: Decimal,
        karat: Int,
        purchaseDate: Date,
        purchasePrice: Decimal,
        currencyCode: String = "SAR",
        invoiceImageData: Data? = nil,
        note: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.weightGrams = weightGrams
        self.karat = karat
        self.purchaseDate = purchaseDate
        self.purchasePrice = purchasePrice
        self.currencyCode = currencyCode
        self.invoiceImageData = invoiceImageData
        self.note = note
        self.createdAt = createdAt
    }
}

/// Gold zakat rules (standard fiqh values).
enum Zakat {
    /// Nisab threshold: 85 grams of pure gold.
    static let nisabGrams: Decimal = 85
    /// Zakat rate: 2.5%.
    static let rate: Decimal = 0.025

    static let karats = [24, 22, 21, 18]
}
