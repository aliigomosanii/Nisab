import Foundation

/// Fetches the current gold price. Primary source for SAR is the Saudi
/// market feed at ounce.com.sa; fallback (and other currencies) uses
/// gold-api.com XAU/USD converted via open.er-api.com FX rates.
/// Read-only; the manual price field remains the fallback and source
/// of truth — a fetch only pre-fills it.
enum GoldPriceService {
    private static let gramsPerTroyOunce = Decimal(string: "31.1034768")!

    /// Today's 24k gold price per gram in the given currency, rounded to 2 places.
    static func pricePerGram24k(currency: String) async -> Decimal? {
        if currency == "SAR", let saudi = await ouncePrice24kSAR() {
            return saudi
        }
        return await pricePerGram(symbol: "XAU", currency: currency)
    }

    /// Saudi 24k price per gram in SAR from ounce.com.sa.
    private static func ouncePrice24kSAR() async -> Decimal? {
        struct Payload: Decodable {
            struct Prices: Decodable {
                let k24: Double
                enum CodingKeys: String, CodingKey { case k24 = "24k" }
            }
            let success: Bool
            let prices: Prices
        }
        guard let payload = await fetchJSON(Payload.self, from: "https://ounce.com.sa/wp-json/sagold/v1/prices"),
              payload.success, payload.prices.k24 > 0 else {
            return nil
        }
        var value = Decimal(payload.prices.k24)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 2, .plain)
        return rounded
    }

    /// Today's silver price per gram in the given currency, rounded to 2 places.
    static func silverPricePerGram(currency: String) async -> Decimal? {
        await pricePerGram(symbol: "XAG", currency: currency)
    }

    private static func pricePerGram(symbol: String, currency: String) async -> Decimal? {
        guard let ounceUSD = await metalOunceUSD(symbol) else { return nil }

        let rate: Decimal
        if currency == "USD" {
            rate = 1
        } else if let fetched = await usdRate(to: currency) {
            rate = fetched
        } else {
            return nil
        }

        var perGram = ounceUSD * rate / gramsPerTroyOunce
        var rounded = Decimal()
        NSDecimalRound(&rounded, &perGram, 2, .plain)
        return rounded
    }

    // MARK: - Private

    private static func fetchJSON<T: Decodable>(_ type: T.Type, from urlString: String) async -> T? {
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else {
            return nil
        }
        return try? JSONDecoder().decode(type, from: data)
    }

    /// Metal price in USD per troy ounce (XAU = gold, XAG = silver).
    private static func metalOunceUSD(_ symbol: String) async -> Decimal? {
        struct Payload: Decodable { let price: Double }
        guard let payload = await fetchJSON(Payload.self, from: "https://api.gold-api.com/price/\(symbol)"),
              payload.price > 0 else {
            return nil
        }
        return Decimal(payload.price)
    }

    /// USD → target currency rate.
    private static func usdRate(to currency: String) async -> Decimal? {
        struct Payload: Decodable { let rates: [String: Double] }
        guard let payload = await fetchJSON(Payload.self, from: "https://open.er-api.com/v6/latest/USD"),
              let rate = payload.rates[currency], rate > 0 else {
            return nil
        }
        return Decimal(rate)
    }
}
