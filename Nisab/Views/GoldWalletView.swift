import SwiftUI
import SwiftData

/// The Jewelry Wallet: a pure inventory of the user's jewelry.
/// All zakat computation lives in the Zakat Calculator tab.
struct GoldWalletView: View {
    @Query(sort: \GoldItem.purchaseDate, order: .reverse) private var items: [GoldItem]
    @State private var showingAdd = false

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "No jewelry yet",
                    systemImage: "circle.hexagongrid.fill",
                    description: Text("Tap + to add your jewelry")
                )
            } else {
                List {
                    Section("Jewelry") {
                        ForEach(items) { item in
                            NavigationLink(value: item.id) {
                                JewelryRow(item: item)
                            }
                        }
                    }
                }
            }
        }
        .navigationDestination(for: UUID.self) { id in
            if let item = items.first(where: { $0.id == id }) {
                GoldItemDetailView(item: item)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Jewelry Item")
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddGoldItemView()
        }
    }
}

private struct JewelryRow: View {
    let item: GoldItem

    var body: some View {
        HStack(spacing: 10) {
            if let data = item.itemImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name.isEmpty ? item.summaryLine : item.name)
                        .font(.headline)
                    Text(item.material.title)
                        .font(.caption2.bold())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                }
                if !item.name.isEmpty {
                    Text(item.summaryLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(item.purchaseDate.dualCalendarString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.purchasePrice.formatted(.currency(code: item.currencyCode)))
                    .font(.subheadline)
                HStack(spacing: 4) {
                    if item.invoiceImageData != nil {
                        Image(systemName: "doc.text.image")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if item.certificateImageData != nil {
                        Image(systemName: "checkmark.seal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
