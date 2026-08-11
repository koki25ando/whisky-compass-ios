import Foundation

/// APIのレスポンス表現。`whisky-compass-web/api/serializers.py` と1対1で対応させること。
/// サーバー側のフィールド名を変えたら必ずここも直す。
///
/// キーはすべてsnake_caseなので、デコーダ側で `.convertFromSnakeCase` を使い、
/// プロパティはcamelCaseのまま書く（CodingKeysを全部書くと差分が読みにくくなるため）。

struct TokenPairDTO: Decodable {
    let access: String
    let refresh: String?
}

struct SignUpResponseDTO: Decodable {
    let user: UserDTO
    let access: String
    let refresh: String
}

struct UserDTO: Decodable, Identifiable, Equatable {
    let userId: String
    let email: String
    let displayName: String
    let avatarUrl: String

    var id: String { userId }
}

struct WhiskyDTO: Decodable, Identifiable, Equatable {
    let whiskyId: String
    let name: String
    let distilleryName: String
    let region: String
    let dataSource: String

    var id: String { whiskyId }
}

struct WhiskySummaryDTO: Decodable, Equatable {
    let total: Int
    let avgRating: Double?
    let flavorCount: Int
    /// 0〜10のUIスケール。記録が無ければ空。
    let flavors: [String: Double]
}

struct WhiskyDetailDTO: Decodable, Identifiable, Equatable {
    let whiskyId: String
    let name: String
    let distilleryName: String
    let region: String
    let type: String
    let ageStatement: Int?
    let abv: Double?
    let summary: WhiskySummaryDTO

    var id: String { whiskyId }
}

struct CheckInPhotoDTO: Decodable, Identifiable, Equatable {
    let checkInPhotoId: String
    let url: String

    var id: String { checkInPhotoId }
}

struct CheckInDTO: Decodable, Identifiable, Equatable {
    let checkInId: String
    let user: UserDTO
    let whisky: WhiskyDTO?
    let whiskyName: String
    let rating: Int
    let note: String
    let drankAt: String
    let createdAt: String
    let photos: [CheckInPhotoDTO]
    /// 0〜10のUIスケール。DB側の0〜1正規化はサーバー内部に閉じている。
    /// 空 = ユーザーがフレーバーを記録しなかった（「全部5」ではない）。
    let flavors: [String: Double]
    let isMine: Bool

    var id: String { checkInId }
}

/// DRFのCursorPaginationの応答形。`next`はカーソル付きの絶対URL。
struct PageDTO<T: Decodable>: Decodable {
    let next: String?
    let previous: String?
    let results: [T]
}

struct StatsDTO: Decodable, Equatable {
    let total: Int
    let avgRating: Double?
    let thisMonth: Int
}
