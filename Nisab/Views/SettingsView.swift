import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(L10n.storageKey) private var appLanguage = "system"
    @State private var pendingLanguage = ""
    @State private var showingRestartAlert = false
    @AppStorage("profileName") private var profileName = ""
    @AppStorage("profileEmail") private var profileEmail = ""
    @AppStorage("profilePhone") private var profilePhone = ""
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var passwordMessage: LocalizedStringKey?
    @State private var passwordChangeSucceeded = false
    // Shared with the gold price section so one currency drives the app.
    @AppStorage("goldPriceCurrency") private var currencyCode = "SAR"
    @AppStorage("defaultKarat") private var defaultKarat = 24

    private static let currencies = ["SAR", "USD", "AED", "PKR", "INR", "EGP", "EUR"]

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    /// Saves the choice, then closes the app gracefully (suspend → exit)
    /// so the new language applies from the next launch.
    private func applyLanguageAndExit() {
        appLanguage = pendingLanguage
        UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            exit(0)
        }
    }

    private func changePassword() {
        passwordChangeSucceeded = false
        guard currentPassword == Keychain.password() else {
            passwordMessage = "Current password is incorrect."
            return
        }
        guard newPassword.count >= 4 else {
            passwordMessage = "Password must be at least 4 characters."
            return
        }
        Keychain.setPassword(newPassword)
        passwordChangeSucceeded = true
        passwordMessage = "Password updated."
        currentPassword = ""
        newPassword = ""
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $profileName)
                    TextField("Email", text: $profileEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Phone", text: $profilePhone)
                        .keyboardType(.phonePad)
                }

                Section("Change Password") {
                    SecureField("Current Password", text: $currentPassword)
                    SecureField("New Password", text: $newPassword)
                    if let passwordMessage {
                        Text(passwordMessage)
                            .font(.caption)
                            .foregroundStyle(passwordChangeSucceeded ? .green : .red)
                    }
                    Button("Change Password") { changePassword() }
                        .disabled(currentPassword.isEmpty || newPassword.isEmpty)
                }

                Section("Preferences") {
                    Picker("Default currency", selection: $currencyCode) {
                        ForEach(Self.currencies, id: \.self) { Text($0) }
                    }
                    Picker("Default karat", selection: $defaultKarat) {
                        ForEach(Zakat.karats, id: \.self) { Text("\($0)K") }
                    }
                }

                Section("Language") {
                    Picker("Language", selection: $pendingLanguage) {
                        Text("System").tag("system")
                        Text(verbatim: "English").tag("en")
                        Text(verbatim: "العربية").tag("ar")
                        Text(verbatim: "اردو").tag("ur")
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: version)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { pendingLanguage = appLanguage }
            .onChange(of: pendingLanguage) { _, newValue in
                if newValue != appLanguage {
                    showingRestartAlert = true
                }
            }
            .alert("Restart Required", isPresented: $showingRestartAlert) {
                Button("Cancel", role: .cancel) { pendingLanguage = appLanguage }
                Button("OK") { applyLanguageAndExit() }
            } message: {
                Text("The app will close to apply the new language. Reopen it to continue.")
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
