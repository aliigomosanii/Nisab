import Foundation
import UserNotifications

/// Local reminders for upcoming zakat due dates (aggregate hawl).
/// Rescheduled from every mutation point so pending reminders always
/// reflect the current holdings and payments.
enum NotificationService {
    private static let identifiers = [
        "zakat.gold.due", "zakat.gold.week",
        "zakat.silver.due", "zakat.silver.week",
    ]

    /// Recomputes both metals' due dates and replaces all pending reminders.
    static func reschedule(items: [GoldItem]) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        guard granted else { return }

        schedule(
            due: items.goldZakatDueDate(),
            dueID: "zakat.gold.due", weekID: "zakat.gold.week",
            dueBody: String(localized: "Your gold zakat is due today.", bundle: L10n.bundle),
            weekBody: String(localized: "Your gold zakat is due in 7 days.", bundle: L10n.bundle)
        )
        schedule(
            due: items.silverZakatDueDate(),
            dueID: "zakat.silver.due", weekID: "zakat.silver.week",
            dueBody: String(localized: "Your silver zakat is due today.", bundle: L10n.bundle),
            weekBody: String(localized: "Your silver zakat is due in 7 days.", bundle: L10n.bundle)
        )
    }

    private static func schedule(due: Date?, dueID: String, weekID: String, dueBody: String, weekBody: String) {
        guard let due, due > .now else { return }
        add(id: dueID, date: due, body: dueBody)
        if let week = Calendar.current.date(byAdding: .day, value: -7, to: due), week > .now {
            add(id: weekID, date: week, body: weekBody)
        }
    }

    private static func add(id: String, date: Date, body: String) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Zakat is due", bundle: L10n.bundle)
        content.body = body
        content.sound = .default
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        comps.hour = 9
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        )
    }
}
