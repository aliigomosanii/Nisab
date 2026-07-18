import SwiftUI

private enum ZakatMode: String, CaseIterable, Identifiable {
    case calculator, wallet
    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .calculator: "Calculator"
        case .wallet: "Gold Wallet"
        }
    }
}

struct ZakatView: View {
    @State private var mode: ZakatMode = .calculator
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .calculator: GoldCalculatorView()
                case .wallet: GoldWalletView()
                }
            }
            .navigationTitle("Zakat")
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
