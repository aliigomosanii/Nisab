import SwiftUI
import SwiftData

/// The Jewelry Wallet: a pure inventory of the user's jewelry.
/// All zakat computation lives in the Zakat Calculator.
struct GoldWalletView: View {
    @Query(sort: \GoldItem.purchaseDate, order: .reverse) private var items: [GoldItem]
    @AppStorage("goldPrice24kText") private var storedGoldPrice = ""
    @AppStorage("silverPriceText") private var storedSilverPrice = ""
    @AppStorage("goldPriceCurrency") private var priceCurrency = "SAR"
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
                    Section {
                        summaryCard
                    }
                    Section {
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
                            .contextMenu {
                                Button {
                                    editingItem = item
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                            }
                        }
                    } header: {
                        Text("Jewelry")
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
        .task {
            // Make sure a price exists so Total worth can show.
            if Decimal(string: storedGoldPrice) == nil,
               let price = await GoldPriceService.pricePerGram24k(currency: priceCurrency) {
                storedGoldPrice = "\(price)"
            }
        }
    }

    /// Hero summary: total worth first, weights beneath.
    private var summaryCard: some View {
        let gold = items.filter { $0.material != .silver }
            .reduce(Decimal(0)) { $0 + $1.weightGrams }
            .formatted(.number.precision(.fractionLength(0...2)))
        let silverGrams = items.filter { $0.material == .silver }
            .reduce(Decimal(0)) { $0 + $1.weightGrams }
        return VStack(alignment: .leading, spacing: 4) {
            if let worth = totalWorth {
                Text("Total worth")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(worth.formatted(.currency(code: priceCurrency)))
                    .font(.title2.bold())
                    .foregroundStyle(Color.accentColor)
            }
            Group {
                if silverGrams > 0 {
                    Text("Gold: \(gold) g · Silver: \(silverGrams.formatted(.number.precision(.fractionLength(0...2)))) g")
                } else {
                    Text("Gold: \(gold) g")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    /// Sum of expected selling prices (metal value minus manufacturing)
    /// across items whose needed price is available.
    private var totalWorth: Decimal? {
        let gold = Decimal(string: storedGoldPrice)
        let silver = Decimal(string: storedSilverPrice)
        let values = items.compactMap {
            $0.expectedSellingPrice(goldPricePerGram24k: gold, silverPricePerGram: silver)
        }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
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
            } else {
                // Placeholder keeps row geometry consistent without a photo.
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "circle.hexagongrid.fill")
                            .foregroundStyle(Color.accentColor)
                    }
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
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.2), in: Capsule())
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
