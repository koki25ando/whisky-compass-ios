import SwiftUI

/// 画面遷移の宛先。`NavigationStack(path:)` に積む値。
enum Route: Hashable {
    case checkIn(String)
    case whisky(String)
    case myPage
}

@Observable
@MainActor
final class SessionModel {
    /// nil = 判定中（Keychainの読み出しは非同期）。
    var hasSession: Bool?

    func refresh() {
        Task { @MainActor in
            hasSession = await AuthRepository.shared.hasSession()
        }
    }
}

struct RootView: View {
    @State private var session = SessionModel()
    @State private var path = NavigationPath()
    @State private var authMode: AuthView.Mode = .logIn

    var body: some View {
        Group {
            switch session.hasSession {
            case .none:
                // トークンの有無が確定するまでは描画しない。ここでログイン画面を出すと、
                // ログイン済みでも一瞬ちらつく。
                ProgressView().appBackground()

            case .some(false):
                AuthView(
                    mode: authMode,
                    onFinished: { session.refresh() },
                    onSwitchMode: { authMode = authMode == .logIn ? .signUp : .logIn }
                )

            case .some(true):
                NavigationStack(path: $path) {
                    HomeView(onOpenMyPage: { path.append(Route.myPage) })
                        .navigationDestination(for: Route.self) { route in
                            switch route {
                            case .checkIn(let id):
                                CheckInDetailView(checkInId: id)
                            case .whisky(let id):
                                WhiskyDetailView(whiskyId: id)
                            case .myPage:
                                MyPageView(onLoggedOut: {
                                    path = NavigationPath()
                                    session.refresh()
                                })
                            }
                        }
                }
            }
        }
        .task { session.refresh() }
    }
}
