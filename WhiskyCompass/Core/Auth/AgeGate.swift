import Foundation

/// 法定飲酒年齢の確認状態。
///
/// このアプリはアルコールを扱うため、初回起動時に「飲酒可能な年齢か」を明示的に確認する。
/// App Store は配信国の法令に沿った年齢確認を求めており、確認導線が無いと審査で止まる。
///
/// 配信対象は**日本とアメリカのみ**（App Store Connect の Availability で設定）。
/// 法定年齢が国で違う（日本20歳／アメリカ21歳）ため、端末のリージョンで出し分ける。
///
/// 保存先は UserDefaults。秘密情報ではないので Keychain には置かない。
/// UserDefaults は Apple の「必要理由API」に該当するため、
/// PrivacyInfo.xcprivacy で用途（CA92.1＝アプリ自身の設定の読み書き）を申告している。
enum AgeGate {

    private static let confirmedKey = "ageGate.confirmed"
    private static let minimumAgeKey = "ageGate.minimumAge"
    private static let confirmedAtKey = "ageGate.confirmedAt"

    /// 端末のリージョンから法定飲酒年齢を決める。
    static var minimumAge: Int {
        minimumAge(for: Locale.current.region?.identifier)
    }

    /// リージョン指定版。テストから直接呼べるように分けてある。
    ///
    /// 配信対象は日本とアメリカのみ。判定できない場合は、
    /// 配信国のうち高いほう（21歳）に倒して安全側に寄せる。
    static func minimumAge(for region: String?) -> Int {
        switch region {
        case "JP": return 20
        case "US": return 21
        default: return 21
        }
    }

    static var hasConfirmed: Bool {
        UserDefaults.standard.bool(forKey: confirmedKey)
    }

    /// 確認した年齢と日時も残す。あとから「いつ・何歳基準で同意したか」を追えるようにするため。
    static func confirm() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: confirmedKey)
        defaults.set(minimumAge, forKey: minimumAgeKey)
        defaults.set(Date(), forKey: confirmedAtKey)
    }

    /// 開発・テスト用。通常の利用では呼ばれない。
    static func reset() {
        let defaults = UserDefaults.standard
        for key in [confirmedKey, minimumAgeKey, confirmedAtKey] {
            defaults.removeObject(forKey: key)
        }
    }
}
