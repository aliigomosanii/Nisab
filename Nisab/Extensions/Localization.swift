import SwiftUI

/// In-app language override. "system" follows the phone's language;
/// "en"/"ar"/"ur" force that language app-wide without a restart.
enum L10n {
    static let storageKey = "appLanguage"

    static var overrideCode: String? {
        let raw = UserDefaults.standard.string(forKey: storageKey)
        return (raw == nil || raw == "system") ? nil : raw
    }

    /// Locale for date/number formatting.
    static var locale: Locale {
        overrideCode.map(Locale.init(identifier:)) ?? .autoupdatingCurrent
    }

    /// Bundle for String(localized:) lookups outside the SwiftUI environment
    /// (notifications, share messages).
    static var bundle: Bundle {
        guard let code = overrideCode,
              let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }

    static var layoutDirection: LayoutDirection? {
        guard let code = overrideCode else { return nil }
        return ["ar", "ur"].contains(code) ? .rightToLeft : .leftToRight
    }
}

private struct LanguageAware: ViewModifier {
    // Observed so the whole hierarchy re-renders when the choice changes.
    @AppStorage(L10n.storageKey) private var appLanguage = "system"

    func body(content: Content) -> some View {
        if let direction = L10n.layoutDirection {
            content
                .environment(\.locale, L10n.locale)
                .environment(\.layoutDirection, direction)
        } else {
            content
        }
    }
}

extension View {
    /// Apply at the app root to honor the in-app language choice.
    func languageAware() -> some View { modifier(LanguageAware()) }
}
