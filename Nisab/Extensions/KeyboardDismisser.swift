import UIKit

/// Installs a window-level tap recognizer so tapping outside any text
/// field dismisses the keyboard — everywhere, including sheets.
enum KeyboardDismisser {
    private final class SimultaneousDelegate: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }

    private static let delegate = SimultaneousDelegate()
    private static var installed = false

    static func install() {
        guard !installed,
              let window = UIApplication.shared.connectedScenes
                  .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
                  .first else {
            return
        }
        let tap = UITapGestureRecognizer(target: window, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        tap.requiresExclusiveTouchType = false
        tap.delegate = delegate
        window.addGestureRecognizer(tap)
        installed = true
    }
}
