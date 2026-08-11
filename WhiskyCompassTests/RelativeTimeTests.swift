import XCTest
@testable import WhiskyCompass

/// 相対時刻の表示。フィードの全カードに出るため、崩れると一目で分かる場所。
/// Android版の TimeTest と同じケースを揃えてある（表示が食い違わないように）。
final class RelativeTimeTests: XCTestCase {

    private let now = ISO8601DateFormatter().date(from: "2026-08-11T12:00:00Z")!

    func testJustNowUnderAMinute() {
        XCTAssertEqual(RelativeTime.relative("2026-08-11T11:59:30Z", now: now), "just now")
    }

    func testMinutesHoursAndDays() {
        XCTAssertEqual(RelativeTime.relative("2026-08-11T11:55:00Z", now: now), "5m ago")
        XCTAssertEqual(RelativeTime.relative("2026-08-11T09:00:00Z", now: now), "3h ago")
        XCTAssertEqual(RelativeTime.relative("2026-08-09T12:00:00Z", now: now), "2d ago")
    }

    func testFallsBackToDateBeyondAWeek() {
        // 「52d ago」は結局読み手が計算する羽目になるので、日付を出す。
        let result = RelativeTime.relative("2026-06-01T12:00:00Z", now: now)
        XCTAssertTrue(result.contains("2026"), "got \(result)")
    }

    func testAcceptsOffsetFormatDjangoReturns() {
        // DRFはUSE_TZ=Trueのため +09:00 のようなオフセット付きで返すことがある。
        XCTAssertEqual(RelativeTime.relative("2026-08-11T20:00:00+09:00", now: now), "1h ago")
    }

    func testAcceptsFractionalSeconds() {
        // Djangoは秒の小数部を含めて返す場合がある。
        XCTAssertEqual(RelativeTime.relative("2026-08-11T11:55:00.123456Z", now: now), "5m ago")
    }

    func testUnparseableInputIsPassedThrough() {
        XCTAssertEqual(RelativeTime.relative("not a date", now: now), "not a date")
    }

    func testFutureTimestampsDoNotRenderAsNegative() {
        // 端末とサーバーの時計がずれていると未来の時刻が来る。
        XCTAssertEqual(RelativeTime.relative("2026-08-11T12:05:00Z", now: now), "just now")
    }
}
