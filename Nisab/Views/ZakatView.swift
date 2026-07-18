import SwiftUI

private enum ZakatMode: String, CaseIterable, Identifiable {
    case wallet, calculator
    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .wallet: "Jewelry Wallet"
        case .calculator: "Zakat Calculator"
        }
    }
}

struct ZakatView: View {
    @State private var mode: ZakatMode = .wallet
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .wallet: GoldWalletView()
                case .calculator: GoldCalculatorView()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .principal) {
                    Picker("Mode", selection: $mode) {
                        ForEach(ZakatMode.allCases) { m in
                            Text(m.title).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
}

#Preview {
    ZakatView()
        .modelContainer(for: [GoldItem.self], inMemory: true)
}
