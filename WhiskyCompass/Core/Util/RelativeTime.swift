import Foundation

/// APIのISO 8601文字列を「3h ago」のような相対表記にする。
/// Android版の `Time.kt` と同じ規則にしてある（表示が端末で食い違わないように）。
enum RelativeTime {

    private static let isoWithFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// DjangoはUSE_TZ=Trueのため `+09:00` のようなオフセット付きで返す。
    /// 小数秒が付く場合と付かない場合の両方が来るので、順に試す。
    static func parse(_ value: String) -> Date? {
        isoWithFraction.date(from: value) ?? iso.date(from: value)
    }

    /// 一覧向けの相対表記。1週間より前は日付を出す
    /// （「52d ago」は結局読み手が計算する羽目になるため）。
    static func relative(_ value: String, now: Date = Date()) -> String {
        guard let date = parse(value) else { return value }

        let elapsed = now.timeIntervalSince(date)
        if elapsed < 60 { return "just now" }
        if elapsed < 3600 { return "\(Int(elapsed / 60))m ago" }
        if elapsed < 86_400 { return "\(Int(elapsed / 3600))h ago" }
        if elapsed < 604_800 { return "\(Int(elapsed / 86_400))d ago" }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    /// 詳細画面向けの絶対表記。
    static func absolute(_ value: String) -> String {
        guard let date = parse(value) else { return value }
        return absolute(date)
    }

    static func absolute(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy · HH:mm"
        return formatter.string(from: date)
    }

    /// APIに送る形式。サーバーは任意の記録日時を受け付ける。
    static func iso8601(_ date: Date) -> String {
        iso.string(from: date)
    }
}
