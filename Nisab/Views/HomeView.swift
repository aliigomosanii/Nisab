import SwiftUI
import SwiftData

/// Nisab home: personalized greeting plus a card for every feature.
struct HomeView: View {
    @Query(sort: \GoldItem.purchaseDate, order: .reverse) private var items: [GoldItem]
    @AppStorage("profileName") private var profileName = ""
    @State private var showingSettings = false
    @State private var showingPayZakat = false

    private var eligible: [GoldItem] { items.filter { !$0.isZakatExempt } }

    private var initials: String {
        profileName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
    }

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    profileHeader

                    LazyVGrid(columns: columns, spacing: 12) {
                        NavigationLink {
                            GoldWalletView()
                                .navigationTitle("Jewelry Wallet")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            card("Jewelry Wallet", caption: "Your jewelry items", icon: "circle.hexagongrid.fill")
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            GoldCalculatorView()
                                .navigationTitle("Zakat Calculator")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            card("Zakat Calculator", caption: "Calculate what's due", icon: "moon.stars.fill")
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            BuySellCalculatorView()
                                .navigationTitle("Buy & Sell Calculator")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            card("Buy & Sell Calculator", caption: "Estimate buying and selling prices", icon: "arrow.left.arrow.right.circle.fill")
                        }
                        .buttonStyle(.plain)

                        Button {
                            showingPayZakat = true
                        } label: {
                            card("Record Zakat Payment", caption: "Record a payment", icon: "checkmark.seal.fill")
                        }
                        .buttonStyle(.plain)

                        Button {
                            showingSettings = true
                        } label: {
                            card("Settings", caption: "App settings", icon: "gearshape.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tejoury")
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingPayZakat) {
                PayZakatView(items: eligible)
            }
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.gradient)
                    .frame(width: 52, height: 52)
                if initials.isEmpty {
                    Image(systemName: "person.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                } else {
                    Text(initials)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                if profileName.isEmpty {
                    Text("Salam!")
                        .font(.title3.bold())
                } else {
                    Text("Salam, \(profileName)!")
                        .font(.title3.bold())
                        .lineLimit(1)
                }
                Text(Date.now.dualCalendarString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if profileName.isEmpty {
                    Button("Set up your profile") {
                        showingSettings = true
                    }
                    .font(.caption.bold())
                }
            }
            Spacer()
        }
    }

    private func card(_ title: LocalizedStringKey, caption: LocalizedStringKey, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.leading)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [GoldItem.self], inMemory: true)
}
