import SwiftUI

@main
struct WhiskyCompassApp: App {

    init() {
        // UIテストが年齢確認を繰り返し検証できるようにする。
        // 起動引数はテストからしか渡らないので、通常利用の挙動は変わらない。
        if ProcessInfo.processInfo.arguments.contains("-uitest-reset-age-gate") {
            AgeGate.reset()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                // Web版・Android版と同じくダーク基調で固定する。
                .preferredColorScheme(.dark)
        }
    }
}
