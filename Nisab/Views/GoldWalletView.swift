import SwiftUI
import SwiftData

/// The Jewelry Wallet: a pure inventory of the user's jewelry.
/// All zakat computation lives in the Zakat Calculator.
struct GoldWalletView: View {
    @Query(sort: \GoldItem.purchaseDate, order: .reverse) private var items: [GoldItem]
    @State private var showingAdd = false
    @State private var editingItem: GoldItem?

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
                            NavigationLink {
                                GoldItemDetailView(item: item)
                            } label: {
                                JewelryRow(item: item)
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    editingItem = item
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
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
        .sheet(item: $editingItem) { item in
            AddGoldItemView(editingItem: item)
        }
    }
}

private struct JewelryRow: View {
    let item: GoldItem
    // Decoded once per row appearance, not on every render.
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 10) {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name.isEmpty ? item.summaryLine : item.name)
                    .font(.headline)
                    .lineLimit(1)
                if !item.name.isEmpty {
                    Text(item.summaryLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(item.purchaseDate.dualCalendarString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.material.title)
                    .font(.caption2.bold())
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                Text(item.purchasePrice.formatted(.currency(code: item.currencyCode)))
                    .font(.subheadline)
                    .lineLimit(1)
            }
        }
        .onAppear { reloadThumbnail() }
        .onChange(of: item.itemImageData) { _, _ in reloadThumbnail() }
    }

    private func reloadThumbnail() {
        guard let data = item.itemImageData, let image = UIImage(data: data) else {
            thumbnail = nil
            return
        }
        // Downscale to thumbnail size so list scrolling stays cheap.
        let side: CGFloat = 88
        let scale = min(1, side / min(image.size.width, image.size.height))
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        thumbnail = UIGraphicsImageRenderer(size: target).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
