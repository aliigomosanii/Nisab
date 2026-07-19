import SwiftUI

/// First-launch registration. Everything is stored on this device only —
/// the password becomes the app lock (with Face ID).
struct RegistrationView: View {
    var onComplete: () -> Void

    @AppStorage("profileName") private var profileName = ""
    @AppStorage("profileEmail") private var profileEmail = ""
    @AppStorage("profilePhone") private var profilePhone = ""
    @AppStorage("profileRegistered") private var registered = false

    // Draft state: nothing is persisted until Continue succeeds.
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: LocalizedStringKey?

    private var formFilled: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !email.trimmingCharacters(in: .whitespaces).isEmpty
            && !phone.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
            && !confirmPassword.isEmpty
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.accentColor)
                    Text("Welcome to Tejoury")
                        .font(.title2.bold())
                    Text("Your information stays on this device only.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)

            Section("Profile") {
                TextField("Name", text: $name)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Phone", text: $phone)
                    .keyboardType(.phonePad)
            }

            Section("Password") {
                PasswordField(titleKey: "Password", text: $password, contentType: .newPassword)
                PasswordField(titleKey: "Confirm Password", text: $confirmPassword, contentType: .newPassword)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    submit()
                } label: {
                    Text("Continue")
                        .bold()
                        .frame(maxWidth: .infinity)
                }
                .disabled(!formFilled)
            }
        }
    }

    private func submit() {
        guard email.contains("@") else {
            errorMessage = "Enter a valid email."
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }
        profileName = name.trimmingCharacters(in: .whitespaces)
        profileEmail = email.trimmingCharacters(in: .whitespaces)
        profilePhone = phone.trimmingCharacters(in: .whitespaces)
        Keychain.setPassword(password)
        registered = true
        onComplete()
    }
}

#Preview {
    RegistrationView {}
}
