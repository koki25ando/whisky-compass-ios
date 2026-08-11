import Foundation

/// チェックイン一覧の取得とページング。
///
/// ホームとマイページで同じものを使い、取得元だけを`source`で切り替える。
/// 継承で分けないのは、`@Observable`がクラス継承と噛み合わず、
/// サブクラスで宣言したプロパティが監視されないため。
@Observable
@MainActor
final class CheckInListViewModel {

    enum Source {
        /// 全ユーザーの最近の記録。
        case feed
        /// 自分の記録だけ。
        case mine
    }

    var checkIns: [CheckInDTO] = []
    var isLoading = true
    var isLoadingMore = false
    var error: String?
    /// カーソルページングの次ページURL。nilなら末尾。
    private(set) var nextURL: String?

    private let source: Source
    private let repository = CheckInRepository.shared
    private var changeObserver: NSObjectProtocol?

    init(source: Source) {
        self.source = source
        // 記録が作成・更新・削除されたら取り直す。画面のライフサイクルに頼ると
        // 「戻ってきたのに消したはずの記録が残る」取りこぼしが起きる
        // （Android版で実際に踏んだ問題と同じ対処）。
        changeObserver = NotificationCenter.default.addObserver(
            forName: CheckInRepository.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    deinit {
        if let changeObserver {
            NotificationCenter.default.removeObserver(changeObserver)
        }
    }

    func refresh() {
        error = nil
        Task { @MainActor in
            do {
                let page = switch source {
                case .feed: try await repository.feed()
                case .mine: try await repository.myCheckIns()
                }
                checkIns = page.results
                nextURL = page.next
            } catch let apiError as APIError {
                error = apiError.message
            } catch {
                self.error = APIError.unknown.message
            }
            isLoading = false
        }
    }

    /// 一覧の末尾が近づいたときに呼ぶ。多重発火しても1回しか走らない。
    func loadMore() {
        guard let next = nextURL, !isLoadingMore else { return }
        isLoadingMore = true

        Task { @MainActor in
            do {
                let page = try await repository.page(next)
                checkIns.append(contentsOf: page.results)
                nextURL = page.next
            } catch let apiError as APIError {
                error = apiError.message
            } catch {
                self.error = APIError.unknown.message
            }
            isLoadingMore = false
        }
    }

    /// 末尾から3件手前に来たら次ページを取りに行く。
    func loadMoreIfNeeded(currentItem: CheckInDTO) {
        guard let index = checkIns.firstIndex(where: { $0.id == currentItem.id }) else { return }
        if index >= checkIns.count - 3 { loadMore() }
    }
}

/// ログイン中のユーザー情報と統計。マイページのヘッダーとホームのアバターで使う。
@Observable
@MainActor
final class ProfileViewModel {

    var user: UserDTO?
    var stats: StatsDTO?
    var loggedOut = false
    var isDeleting = false
    var deleteError: String?

    private let authRepository = AuthRepository.shared
    private let repository = CheckInRepository.shared

    /// 取れなくても画面は成立させたいので、失敗は握り潰す。
    func load(includeStats: Bool = true) {
        Task { @MainActor in
            user = try? await authRepository.me()
            if includeStats { stats = try? await repository.stats() }
        }
    }

    func logOut() {
        Task { @MainActor in
            await authRepository.logOut()
            loggedOut = true
        }
    }

    /// アカウント削除。成功すればログアウトと同じ扱いで認証画面へ戻す。
    /// パスワード確認はサーバー側で行うため、間違っていれば削除されずエラーが返る。
    func deleteAccount(password: String) {
        guard !isDeleting else { return }
        isDeleting = true
        deleteError = nil

        Task { @MainActor in
            do {
                try await authRepository.deleteAccount(password: password)
                loggedOut = true
            } catch let apiError as APIError {
                deleteError = apiError.fieldErrors["password"] ?? apiError.message
            } catch {
                deleteError = APIError.unknown.message
            }
            isDeleting = false
        }
    }
}
