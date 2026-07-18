import SwiftUI
import SwiftData

@main
struct NisabApp: App {
    var body: some Scene {
        WindowGroup {
            ZakatView()
        }
        .modelContainer(for: [GoldItem.self])
    }
}
