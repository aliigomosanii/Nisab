import SwiftUI
import LocalAuthentication

/// App lock: unlock with the registered password or Face ID.
struct LockView: View {
    var onUnlock: () -> Void

    @State private var passwordText = ""
    @State private var wrongPassword = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)
            Text("Tejoury")
                .font(.largeTitle.bold())

            SecureField("Enter password", text: $passwordText)
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

            Button {
                tryBiometrics()
            } label: {
                Label("Unlock with Face ID", systemImage: "faceid")
            }
            Spacer()
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear { tryBiometrics() }
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
}

#Preview {
    LockView {}
}
