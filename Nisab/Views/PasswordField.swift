import SwiftUI

/// Secure text field with a show/hide toggle. `contentType` drives the
/// system keychain suggestions (.newPassword offers strong passwords).
struct PasswordField: View {
    let titleKey: LocalizedStringKey
    @Binding var text: String
    var contentType: UITextContentType = .password

    @State private var revealed = false

    var body: some View {
        HStack {
            Group {
                if revealed {
                    TextField(titleKey, text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField(titleKey, text: $text)
                }
            }
            .textContentType(contentType)
            Button {
                revealed.toggle()
            } label: {
                Image(systemName: revealed ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(revealed ? "Hide password" : "Show password")
        }
    }
}
