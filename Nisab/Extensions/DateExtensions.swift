import Foundation

extension Date {
    /// This date in the Umm al-Qura Hijri calendar (the Saudi civil standard),
    /// localized to the user's language.
    var hijriString: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .islamicUmmAlQura)
        formatter.dateStyle = .medium
        return formatter.string(from: self)
    }

    /// Gregorian and Hijri on one line, e.g. "18 Jul 2026 (23 Muh. 1448 AH)".
    var dualCalendarString: String {
        "\(formatted(date: .abbreviated, time: .omitted)) (\(hijriString))"
    }
}
