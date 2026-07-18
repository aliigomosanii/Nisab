import SwiftUI
import SwiftData

@main
struct NisabApp: App {
    var body: some Scene {
        WindowGroup {
            ZakatView()
                .languageAware()
        }
        .modelContainer(for: [GoldItem.self])
    }
}
