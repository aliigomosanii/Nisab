import SwiftUI
import SwiftData

private enum ZakatSheetTab: String, CaseIterable, Identifiable {
    case pay, schedule, history
    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .pay: "Pay"
        case .schedule: "Schedule"
        case .history: "History"
        }
    }
}

/// Records a zakat payment for selected jewelry items, and doubles as the
/// zakat dashboard: upcoming dues and full payment history.
struct PayZakatView: View {
    @Environment(\.dismiss) private var dismiss

    /// Items eligible for payment (not currently exempt).
    let items: [GoldItem]

    /// All items (paid ones included) for the schedule and history.
    @Query(sort: \GoldItem.purchaseDate) private var allItems: [GoldItem]

    @State private var tab: ZakatSheetTab = .pay
    @State private var selectedIDs: Set<UUID>
    @State private var paymentDate = Date.now
    /// Payment date pending delete confirmation in the History tab.
    @State private var deleteCandidate: Date?
    @AppStorage("goldPrice24kText") private var priceText = ""
    @AppStorage("goldPriceCurrency") private var currencyCode = "SAR"

    init(items: [GoldItem]) {
        self.items = items
        _selectedIDs = State(initialValue: Set(items.map(\.id)))
    }

    // MARK: - Pay computation

    private var selectedItems: [GoldItem] {
        items.filter { selectedIDs.contains($0.id) }
    }

    private var selectedPureGrams: Decimal {
        selectedItems.reduce(0) { $0 + $1.pureGoldGrams }
    }

    private var selectedSilverGrams: Decimal {
        selectedItems.reduce(0) { $0 + $1.silverGrams }
    }

    private var zakatGrams: Decimal { selectedPureGrams * Zakat.rate }
    private var silverZakatGrams: Decimal { selectedSilverGrams * Zakat.rate }

    private var goldAboveNisab: Bool { selectedPureGrams >= Zakat.nisabGrams }
    private var silverAboveNisab: Bool { selectedSilverGrams >= Zakat.silverNisabGrams }

    /// Zakat is only due (and thus recordable) when either metal reaches
    /// its own nisab.
    private var aboveNisab: Bool { goldAboveNisab || silverAboveNisab }

    private var zakatValue: Decimal? {
        Decimal(string: priceText).map { selectedPureGrams * $0 * Zakat.rate }
    }

    // MARK: - Schedule & history

    /// First day of the Hijri year after next — the schedule shows dues
    /// up to the end of next year.
    private var scheduleCutoff: Date {
        let calendar = Calendar(identifier: .islamicUmmAlQura)
        let year = calendar.component(.year, from: .now)
        var comps = DateComponents()
        comps.year = year + 2
        comps.month = 1
        comps.day = 1
        return calendar.date(from: comps) ?? .distantFuture
    }

    /// Items with their next due date under the aggregate hawl
    /// (nil = below nisab, no obligation), soonest first, limited to the
    /// end of next Hijri year.
    private var upcomingDues: [(item: GoldItem, due: Date?)] {
        let goldDue = allItems.goldZakatDueDate()
        let silverDue = allItems.silverZakatDueDate()
        return allItems
            .map { item -> (item: GoldItem, due: Date?) in
                if item.isZakatExempt {
                    return (item, item.zakatExemptUntil)
                }
                return (item, item.material == .silver ? silverDue : goldDue)
            }
            .filter { $0.due == nil || $0.due! < scheduleCutoff }
            .sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
    }

    /// Recorded payments grouped by date (items paid together share one
    /// exact date), newest first.
    private var pastPayments: [(date: Date, items: [GoldItem])] {
        var groups: [Date: [GoldItem]] = [:]
        for item in allItems {
            for date in item.paymentHistory {
                groups[date, default: []].append(item)
            }
        }
        return groups
            .map { (date: $0.key, items: $0.value) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Mode", selection: $tab) {
                        ForEach(ZakatSheetTab.allCases) { t in
                            Text(t.title).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                switch tab {
                case .pay: paySections
                case .schedule: scheduleSection
                case .history: historySection
                }
            }
            .navigationTitle("Record Zakat Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if tab == .pay {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { save() }
                            .disabled(!aboveNisab)
                    }
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var paySections: some View {
        Section("Jewelry") {
            if items.isEmpty {
                Text("All zakat is paid — nothing is currently due.")
                    .foregroundStyle(.secondary)
            }
            ForEach(items) { item in
                Button {
                    if selectedIDs.contains(item.id) {
                        selectedIDs.remove(item.id)
                    } else {
                        selectedIDs.insert(item.id)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name.isEmpty ? item.summaryLine : item.name)
                                .foregroundStyle(.primary)
                            if !item.name.isEmpty {
                                Text(item.summaryLine)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: selectedIDs.contains(item.id)
                              ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedIDs.contains(item.id) ? Color.accentColor : .secondary)
                    }
                }
            }
        }

        if !items.isEmpty {
            Section("Payment Date") {
                DatePicker("Payment Date", selection: $paymentDate, in: ...Date.now, displayedComponents: .date)
                Text(paymentDate.dualCalendarString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        if !selectedItems.isEmpty {
            Section("Result") {
                if selectedPureGrams > 0 {
                    LabeledContent("Pure gold equivalent") {
                        Text("\(selectedPureGrams.formatted(.number.precision(.fractionLength(0...2)))) g")
                    }
                    LabeledContent("Nisab (85g pure gold)") {
                        Text(goldAboveNisab ? "Above nisab" : "Below nisab")
                            .foregroundStyle(goldAboveNisab ? Color.green : .red)
                    }
                    if goldAboveNisab {
                        LabeledContent("Zakat due (2.5%)") {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(zakatGrams.formatted(.number.precision(.fractionLength(0...2)))) g")
                                    .bold()
                                if let zakatValue {
                                    Text(zakatValue.formatted(.currency(code: currencyCode)))
                                        .bold()
                                }
                            }
                        }
                    }
                }
                if selectedSilverGrams > 0 {
                    LabeledContent("Total silver") {
                        Text("\(selectedSilverGrams.formatted(.number.precision(.fractionLength(0...2)))) g")
                    }
                    LabeledContent("Silver nisab (595g)") {
                        Text(silverAboveNisab ? "Above nisab" : "Below nisab")
                            .foregroundStyle(silverAboveNisab ? Color.green : .red)
                    }
                    if silverAboveNisab {
                        LabeledContent("Silver zakat due (2.5%)") {
                            Text("\(silverZakatGrams.formatted(.number.precision(.fractionLength(0...2)))) g")
                                .bold()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var scheduleSection: some View {
        if upcomingDues.isEmpty {
            Section {
                Text("All zakat is paid — nothing is currently due.")
                    .foregroundStyle(.secondary)
            }
        } else {
            Section("Upcoming zakat dates") {
                ForEach(upcomingDues, id: \.item.id) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.item.name.isEmpty ? entry.item.summaryLine : entry.item.name)
                            if !entry.item.name.isEmpty {
                                Text(entry.item.summaryLine)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let due = entry.due {
                            if due <= .now {
                                Text("Due now")
                                    .bold()
                                    .foregroundStyle(.orange)
                            } else {
                                Text(due.dualCalendarString)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.trailing)
                            }
                        } else {
                            Text("Below nisab")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Text("Shows dues until the end of next Hijri year.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        if pastPayments.isEmpty {
            Section {
                Text("No payments yet")
                    .foregroundStyle(.secondary)
            }
        } else {
            Section {
                ForEach(pastPayments, id: \.date) { entry in
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.date.dualCalendarString)
                            ForEach(entry.items) { item in
                                Text(item.name.isEmpty ? item.summaryLine : item.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            deleteCandidate = entry.date
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text("Zakat Payments")
            } footer: {
                Text("Swipe a payment to remove it. The payment is removed from every item it covered.")
            }
            .confirmationDialog(
                "Remove this zakat payment?",
                isPresented: Binding(
                    get: { deleteCandidate != nil },
                    set: { if !$0 { deleteCandidate = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Remove Payment", role: .destructive) {
                    if let date = deleteCandidate {
                        deletePayment(on: date)
                    }
                    deleteCandidate = nil
                }
                Button("Cancel", role: .cancel) { deleteCandidate = nil }
            } message: {
                Text("The payment will be removed from every item it covered, and their zakat becomes due again.")
            }
        }
    }

    /// Removes the payment from every item that shares this exact date and
    /// restores each item's previous payment state.
    private func deletePayment(on date: Date) {
        for item in allItems {
            item.zakatPaymentDates.removeAll { $0 == date }
            if item.lastZakatPaidAt == date {
                item.lastZakatPaidAt = item.zakatPaymentDates.max()
            }
        }
    }

    private func save() {
        for item in selectedItems {
            item.lastZakatPaidAt = paymentDate
            item.zakatPaymentDates.append(paymentDate)
        }
        dismiss()
    }
}
