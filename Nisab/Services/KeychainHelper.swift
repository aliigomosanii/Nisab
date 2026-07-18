import Foundation
import Security

/// Minimal Keychain wrapper for the app-lock password.
enum Keychain {
    private static let service = "com.aligomosani.nisab.applock"
    private static let account = "applock"

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    static func setPassword(_ value: String) {
        SecItemDelete(baseQuery as CFDictionary)
        var add = baseQuery
        add[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(add as CFDictionary, nil)
    }

    static func password() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
