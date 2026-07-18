import SwiftUI

/// First-launch registration. Everything is stored on this device only —
/// the password becomes the app lock (with Face ID).
struct RegistrationView: View {
    var onComplete: () -> Void

    @AppStorage("profileName") private var profileName = ""
    @AppStorage("profileEmail") private var profileEmail = ""
    @AppStorage("profilePhone") private var profilePhone = ""
    @AppStorage("profileRegistered") private var registered = false

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: LocalizedStringKey?

    private var formFilled: Bool {
        !profileName.trimmingCharacters(in: .whitespaces).isEmpty
            && !profileEmail.trimmingCharacters(in: .whitespaces).isEmpty
            && !profilePhone.trimmingCharacters(in: .whitespaces).isEmpty
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
                TextField("Name", text: $profileName)
                TextField("Email", text: $profileEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Phone", text: $profilePhone)
                    .keyboardType(.phonePad)
            }

            Section("Password") {
                SecureField("Password", text: $password)
                SecureField("Confirm Password", text: $confirmPassword)
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
        guard profileEmail.contains("@") else {
            errorMessage = "Enter a valid email."
            return
        }
        guard password.count >= 4 else {
            errorMessage = "Password must be at least 4 characters."
            return
        }
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }
        Keychain.setPassword(password)
        registered = true
        onComplete()
    }
}

#Preview {
    RegistrationView {}
}
