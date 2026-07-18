import SwiftUI
import SwiftData

@main
struct NisabApp: App {
    var body: some Scene {
        WindowGroup {
            RootGateView()
                .languageAware()
        }
        .modelContainer(for: [GoldItem.self])
    }
}

/// Routes between registration, the lock screen, and the app itself.
private struct RootGateView: View {
    @AppStorage("profileRegistered") private var registered = false
    @State private var unlocked = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if !registered {
                RegistrationView { unlocked = true }
            } else if !unlocked {
                LockView { unlocked = true }
            } else {
                HomeView()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Relock whenever the app leaves the foreground.
            if phase == .background {
                unlocked = false
            }
        }
    }
}
