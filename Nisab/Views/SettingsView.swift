import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(L10n.storageKey) private var appLanguage = "system"
    @State private var pendingLanguage = ""
    @State private var showingRestartAlert = false
    @AppStorage("profileName") private var profileName = ""
    @AppStorage("profileEmail") private var profileEmail = ""
    @AppStorage("profilePhone") private var profilePhone = ""
    @State private var showingChangePassword = false
    /// Read by LockView; when off, unlocking is password-only.
    @AppStorage("faceIDEnabled") private var faceIDEnabled = true
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

                Section("Security") {
                    Button("Change Password") { showingChangePassword = true }
                    Toggle("Unlock with Face ID", isOn: $faceIDEnabled)
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
            .sheet(isPresented: $showingChangePassword) {
                ChangePasswordView()
            }
        }
    }
}

/// Guided password change: verify the current password, then set a new one.
private struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var message: LocalizedStringKey?

    private var canSave: Bool {
        !currentPassword.isEmpty && !newPassword.isEmpty && !confirmPassword.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Current Password", text: $currentPassword)
                }
                Section {
                    SecureField("New Password", text: $newPassword)
                    SecureField("Confirm Password", text: $confirmPassword)
                    if let message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        guard currentPassword == Keychain.password() else {
            message = "Current password is incorrect."
            return
        }
        guard newPassword.count >= 4 else {
            message = "Password must be at least 4 characters."
            return
        }
        guard newPassword == confirmPassword else {
            message = "Passwords do not match."
            return
        }
        Keychain.setPassword(newPassword)
        dismiss()
    }
}

#Preview {
    SettingsView()
}
