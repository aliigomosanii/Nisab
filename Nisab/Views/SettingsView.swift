import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(L10n.storageKey) private var appLanguage = "system"
    @AppStorage("profileName") private var profileName = ""
    @AppStorage("profilePhone") private var profilePhone = ""
    // Shared with the gold price section so one currency drives the app.
    @AppStorage("goldPriceCurrency") private var currencyCode = "SAR"
    @AppStorage("defaultKarat") private var defaultKarat = 24

    private static let currencies = ["SAR", "USD", "AED", "PKR", "INR", "EGP", "EUR"]

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $profileName)
                    TextField("Phone", text: $profilePhone)
                        .keyboardType(.phonePad)
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
                    Picker("Language", selection: $appLanguage) {
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
