import Foundation

/// 認証まわり。トークンの保管はAPIClientが持つTokenStoreに集約する。
@MainActor
final class AuthRepository {

    static let shared = AuthRepository()

    private let api = APIClient.shared

    func hasSession() async -> Bool {
        await api.tokenStore.hasSession
    }

    func logIn(email: String, password: String) async throws {
        // TokenObtainPairViewはUSERNAME_FIELDを見るため、キーは"username"ではなく"email"。
        let pair = try await api.postJSON(
            "api/v1/auth/token/",
            body: ["email": email, "password": password],
            as: TokenPairDTO.self
        )
        await api.tokenStore.save(access: pair.access, refresh: pair.refresh)
    }

    func signUp(email: String, displayName: String, password: String) async throws {
        // 年齢確認は起動時に済ませてある。サーバー側にも記録を残すため一緒に送る
        // （APIを直接叩けば確認なしで登録できる、という穴を塞ぐためサーバーでも必須）。
        let response = try await api.postJSON(
            "api/v1/auth/signup/",
            body: [
                "email": email,
                "display_name": displayName,
                "password": password,
                "age_confirmed": true,
                "age_confirmed_minimum": AgeGate.minimumAge,
            ],
            as: SignUpResponseDTO.self
        )
        await api.tokenStore.save(access: response.access, refresh: response.refresh)
    }

    func me() async throws -> UserDTO {
        try await api.get("api/v1/me/", as: UserDTO.self)
    }

    func logOut() async {
        await api.tokenStore.clear()
    }

    /// アカウントと紐づく全データを削除する。
    ///
    /// Google PlayもApp Storeも、アプリ内でアカウントを作れるアプリには
    /// アプリ内からの削除導線を必須にしている。無効化ではなく実削除で、
    /// 記録・写真も一緒に消える。
    func deleteAccount(password: String) async throws {
        try await api.postJSONIgnoringResponse(
            "api/v1/me/delete/",
            body: ["password": password]
        )
        // サーバー側でユーザーが消えているので、手元のトークンも捨てる。
        await api.tokenStore.clear()
    }
}

/// チェックインと銘柄の読み書き。
@MainActor
final class CheckInRepository {

    static let shared = CheckInRepository()

    private let api = APIClient.shared

    /// 記録が作成・更新・削除されたことを知らせる通知。
    ///
    /// 一覧画面はこれを購読して自分で取り直す。画面のライフサイクルや
    /// 戻り値に頼ると「Homeに戻ったのに消したはずの記録が残る」取りこぼしが起きる
    /// （Android版で実際に踏んだ問題と同じ対処）。
    let changes = NotificationCenter.default
    static let didChange = Notification.Name("WhiskyCompass.checkInsDidChange")

    func notifyChanged() {
        changes.post(name: Self.didChange, object: nil)
    }

    func feed() async throws -> PageDTO<CheckInDTO> {
        try await api.get("api/v1/check-ins/", as: PageDTO<CheckInDTO>.self)
    }

    func myCheckIns() async throws -> PageDTO<CheckInDTO> {
        try await api.get("api/v1/me/check-ins/", as: PageDTO<CheckInDTO>.self)
    }

    func page(_ url: String) async throws -> PageDTO<CheckInDTO> {
        try await api.getAbsolute(url, as: PageDTO<CheckInDTO>.self)
    }

    func checkIn(id: String) async throws -> CheckInDTO {
        try await api.get("api/v1/check-ins/\(id)/", as: CheckInDTO.self)
    }

    func stats() async throws -> StatsDTO {
        try await api.get("api/v1/me/stats/", as: StatsDTO.self)
    }

    func searchWhiskies(query: String) async throws -> [WhiskyDTO] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return try await api.get("api/v1/whiskies/?q=\(encoded)", as: [WhiskyDTO].self)
    }

    func whisky(id: String) async throws -> WhiskyDetailDTO {
        try await api.get("api/v1/whiskies/\(id)/", as: WhiskyDetailDTO.self)
    }

    func whiskyCheckIns(id: String) async throws -> PageDTO<CheckInDTO> {
        try await api.get("api/v1/whiskies/\(id)/check-ins/", as: PageDTO<CheckInDTO>.self)
    }

    func delete(id: String) async throws {
        try await api.delete("api/v1/check-ins/\(id)/")
        notifyChanged()
    }

    func save(_ draft: CheckInDraft) async throws -> CheckInDTO {
        let parts = multipartParts(for: draft)
        let saved: CheckInDTO
        if let id = draft.checkInId {
            saved = try await api.sendMultipart(
                "api/v1/check-ins/\(id)/", method: "PATCH", parts: parts, as: CheckInDTO.self
            )
        } else {
            saved = try await api.sendMultipart(
                "api/v1/check-ins/", method: "POST", parts: parts, as: CheckInDTO.self
            )
        }
        notifyChanged()
        return saved
    }

    private func multipartParts(for draft: CheckInDraft) -> [MultipartPart] {
        var parts: [MultipartPart] = [
            .text("whisky_name", draft.whiskyName.trimmingCharacters(in: .whitespacesAndNewlines)),
            .text("rating", String(draft.rating)),
            .text("note", draft.note),
        ]

        if let drankAt = draft.drankAt {
            parts.append(.text("drank_at", RelativeTime.iso8601(drankAt)))
        }

        if draft.recordFlavors {
            for axis in flavorAxes {
                parts.append(.text(axis.key, String(draft.flavors[axis.key] ?? 0)))
            }
        } else if draft.checkInId != nil {
            // 編集でオフにした場合は、既にあるスコアを消すよう明示する。
            parts.append(.text("clear_flavors", "true"))
        }

        // 同名フィールドの繰り返しで配列になる。
        for photoId in draft.removedPhotoIds {
            parts.append(.text("remove_photo_ids", photoId))
        }
        for (index, data) in draft.newPhotos.enumerated() {
            parts.append(.jpeg("photos", filename: "photo_\(index).jpg", data: data))
        }

        return parts
    }
}

/// 通報とブロック。
///
/// App Reviewガイドライン1.2は、他人の投稿を表示するアプリに
/// 「通報できること」「相手をブロックできること」を必須にしている。
/// 実際の絞り込みはサーバー側（`CheckIn.objects.visible_to()`）が行うので、
/// ここは送るだけ。ブロック後は一覧を取り直す必要があるため変更通知を出す。
@MainActor
final class ModerationRepository {

    static let shared = ModerationRepository()

    private let api = APIClient.shared

    func report(checkInId: String, reason: ReportReason, note: String) async throws {
        try await api.postJSONIgnoringResponse(
            "api/v1/check-ins/\(checkInId)/report/",
            body: ["reason": reason.rawValue, "note": note]
        )
    }

    func block(userId: String) async throws {
        try await api.postJSONIgnoringResponse("api/v1/users/\(userId)/block/", body: [:])
        CheckInRepository.shared.notifyChanged()
    }

    func unblock(userId: String) async throws {
        try await api.delete("api/v1/users/\(userId)/block/")
        CheckInRepository.shared.notifyChanged()
    }

    func blockedUsers() async throws -> [BlockedUserDTO] {
        try await api.get("api/v1/me/blocks/", as: [BlockedUserDTO].self)
    }
}

/// 通報理由。サーバーの`Report.Reason`と値を一致させること。
enum ReportReason: String, CaseIterable, Identifiable {
    case spam
    case offensive
    case harassment
    case illegal
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .spam: "Spam or advertising"
        case .offensive: "Offensive or inappropriate"
        case .harassment: "Harassment or hate"
        case .illegal: "Illegal or unsafe"
        case .other: "Something else"
        }
    }
}
