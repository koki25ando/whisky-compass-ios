import Foundation

struct FlavorAxis: Identifiable, Hashable {
    let key: String
    let label: String
    let short: String

    var id: String { key }
}

/// Web版・API（tastings/services.py）と**同じ順序・同じ軸**に揃えること。
/// ズレるとレーダーの軸が入れ替わり、データの意味が変わる。
let flavorAxes: [FlavorAxis] = [
    FlavorAxis(key: "smoky", label: "Smoky / Peaty", short: "Smoky"),
    FlavorAxis(key: "sweet", label: "Sweet / Vanilla", short: "Sweet"),
    FlavorAxis(key: "fruity", label: "Fruity", short: "Fruity"),
    FlavorAxis(key: "woody", label: "Woody / Spicy", short: "Woody"),
    FlavorAxis(key: "rich", label: "Rich / Full-bodied", short: "Rich"),
    FlavorAxis(key: "floral", label: "Floral / Light", short: "Floral"),
]

/// 1件のチェックインに添付できる写真の上限。サーバー側の規則と合わせている。
let maxPhotosPerCheckIn = 5

/// 編集内容。新規作成なら`checkInId`がnil。
struct CheckInDraft {
    var checkInId: String?
    var whiskyName: String = ""
    var rating: Int = 7
    var note: String = ""
    /// 0〜10のUIスケール。サーバー側で0〜1に正規化される。
    var flavors: [String: Int] = Dictionary(uniqueKeysWithValues: flavorAxes.map { ($0.key, 5) })
    /// フレーバーを記録するか。falseなら軸を一切送らない＝サーバーは何も保存しない。
    /// 触っていないスライダーの初期値5を保存すると、プロダクトの資産である
    /// フレーバーデータに意味のない中央値が混ざる。
    var recordFlavors: Bool = false
    var drankAt: Date?
    var newPhotos: [Data] = []
    var removedPhotoIds: [String] = []
}
