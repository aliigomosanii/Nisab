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
    @State private var backgroundedAt: Date?
    @Environment(\.scenePhase) private var scenePhase

    /// Quick app switches within this window don't relock.
    private let graceSeconds: TimeInterval = 30

    var body: some View {
        Group {
            if !registered {
                RegistrationView { unlocked = true }
            } else {
                // The app stays alive under the lock overlay so navigation
                // state survives unlocking.
                ZStack {
                    HomeView()
                    if !unlocked {
                        LockView { unlocked = true }
                            .zIndex(1)
                    }
                }
            }
        }
        .onAppear { KeyboardDismisser.install() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                backgroundedAt = .now
            case .active:
                if unlocked, let at = backgroundedAt,
                   Date.now.timeIntervalSince(at) > graceSeconds {
                    unlocked = false
                }
                backgroundedAt = nil
            default:
                break
            }
        }
    }
}
