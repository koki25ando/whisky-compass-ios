import SwiftUI

/// 画面遷移の宛先。`NavigationStack(path:)` に積む値。
enum Route: Hashable {
    case checkIn(String)
    case whisky(String)
    case myPage
    case blockedAccounts
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
    // 法定飲酒年齢の確認。ログイン画面より前に置くことで、新規登録・ログインの
    // どちらの経路でも必ず通る。
    @State private var ageConfirmed = AgeGate.hasConfirmed
        || ProcessInfo.processInfo.arguments.contains("-uitest-skip-age-gate")

    var body: some View {
        Group {
            if !ageConfirmed {
                AgeGateView { ageConfirmed = true }
            } else {
                authenticatedBody
            }
        }
        .task { session.refresh() }
    }

    @ViewBuilder
    private var authenticatedBody: some View {
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
                // tintはNavigationStackに掛ける。appBackground()の中に置いても
                // ツールバー（戻る・編集・削除）はナビゲーションバーが描くため届かず、
                // iOS既定の青のままになる。
                NavigationStack(path: $path) {
                    HomeView(onOpenMyPage: { path.append(Route.myPage) })
                        .navigationDestination(for: Route.self) { route in
                            switch route {
                            case .checkIn(let id):
                                CheckInDetailView(checkInId: id)
                            case .whisky(let id):
                                WhiskyDetailView(whiskyId: id)
                            case .blockedAccounts:
                                BlockedAccountsView()
                            case .myPage:
                                MyPageView(onLoggedOut: {
                                    path = NavigationPath()
                                    session.refresh()
                                })
                            }
                        }
                }
                .tint(Palette.gold)
            }
        }
    }
}
