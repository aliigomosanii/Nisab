import SwiftUI
import SwiftData

@main
struct NisabApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .languageAware()
        }
        .modelContainer(for: [GoldItem.self])
    }
}
