import SwiftUI

@main
struct WhiskyCompassApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                // Web版・Android版と同じくダーク基調で固定する。
                .preferredColorScheme(.dark)
        }
    }
}
