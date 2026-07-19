import SwiftUI
import LocalAuthentication

/// App lock: unlock with the registered password or Face ID.
struct LockView: View {
    var onUnlock: () -> Void

    @State private var passwordText = ""
    @State private var wrongPassword = false
    @State private var showingReset = false
    @State private var resetUnavailable = false
    /// Settings toggle; when off, unlocking is password-only.
    @AppStorage("faceIDEnabled") private var faceIDEnabled = true

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)
            Text("Tejoury")
                .font(.largeTitle.bold())

            SecureField("Enter password", text: $passwordText)
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 280)
                .onSubmit { tryPassword() }

            if wrongPassword {
                Text("Wrong password.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                tryPassword()
            } label: {
                Text("Unlock")
                    .bold()
                    .frame(maxWidth: 280)
            }
            .buttonStyle(.borderedProminent)
            .disabled(passwordText.isEmpty)

            if faceIDEnabled {
                Button {
                    tryBiometrics()
                } label: {
                    Label("Unlock with Face ID", systemImage: "faceid")
                }
            }

            Button {
                startReset()
            } label: {
                Text("Forgot password? Reset with Face ID")
                    .font(.caption)
            }
            if resetUnavailable {
                Text("Face ID is not available.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Spacer()
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear { tryBiometrics() }
        .sheet(isPresented: $showingReset) {
            ResetPasswordView { onUnlock() }
        }
    }

    private func tryPassword() {
        if passwordText == Keychain.password() {
            onUnlock()
        } else {
            wrongPassword = true
            passwordText = ""
        }
    }

    private func tryBiometrics() {
        guard faceIDEnabled else { return }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return
        }
        let reason = String(localized: "Unlock with Face ID", bundle: L10n.bundle)
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
            if success {
                DispatchQueue.main.async { onUnlock() }
            }
        }
    }

    /// Recovery path: Face ID proves identity even when the password is
    /// forgotten (works regardless of the unlock toggle), then a new
    /// password can be set.
    private func startReset() {
        resetUnavailable = false
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            resetUnavailable = true
            return
        }
        let reason = String(localized: "Reset Password", bundle: L10n.bundle)
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
            if success {
                DispatchQueue.main.async { showingReset = true }
            }
        }
    }
}

/// Sets a new password after a successful Face ID identity check.
private struct ResetPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    var onDone: () -> Void

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var message: LocalizedStringKey?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PasswordField(titleKey: "New Password", text: $newPassword, contentType: .newPassword)
                    PasswordField(titleKey: "Confirm Password", text: $confirmPassword, contentType: .newPassword)
                    if let message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(newPassword.isEmpty || confirmPassword.isEmpty)
                }
            }
        }
    }

    private func save() {
        guard newPassword.count >= 6 else {
            message = "Password must be at least 6 characters."
            return
        }
        guard newPassword == confirmPassword else {
            message = "Passwords do not match."
            return
        }
        Keychain.setPassword(newPassword)
        dismiss()
        onDone()
    }
}

#Preview {
    LockView {}
}
