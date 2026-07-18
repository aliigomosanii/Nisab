import Foundation

extension String {
    /// Strictly numeric decimal input: ASCII/Arabic-Indic/Urdu digits are
    /// normalized to ASCII, with at most one decimal separator kept.
    var sanitizedDecimal: String {
        var result = ""
        var hasSeparator = false
        for char in self {
            if let digit = char.wholeNumberValue, (0...9).contains(digit) {
                result.append(Character("\(digit)"))
            } else if ".,٫".contains(char), !hasSeparator {
                result.append(".")
                hasSeparator = true
            }
        }
        return result
    }
}
