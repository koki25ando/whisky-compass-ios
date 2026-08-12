import XCTest

/// App Store 掲載用のスクリーンショットを撮るためのテスト。
///
/// 検証が目的ではなく**素材の生成**が目的。通常のテスト実行に混ぜたくないので
/// クラスを分けてある（`-only-testing:WhiskyCompassUITests/ScreenshotUITests` で指定）。
///
/// 前提：
/// - ローカルのDjangoが起動していること
/// - フィードに写真つきの記録があること（空の画面はストアに出せない）
///
/// 撮影後は `xcrun xcresulttool export attachments` で xcresult から取り出す。
final class ScreenshotUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest-skip-age-gate"]
        app.launch()
    }

    func testCaptureStoreScreenshots() throws {
        if app.textFields["Email"].waitForExistence(timeout: 10) {
            logIn()
        }
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 20))
        sleep(3)  // 画像の読み込み待ち。読み込み中のカードを撮らないため。
        capture("01-home")

        // --- 記録の詳細（レーダーチャートが写る） ---
        let card = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Year")
        ).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "フィードに記録が無い")
        // 通常の tap() は hittable 判定で弾かれることがあるため座標で叩く。
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.navigationBars["Check-in"].waitForExistence(timeout: 10))
        sleep(2)
        capture("02-detail")

        // --- 銘柄ページ（コミュニティ集計） ---
        // 詳細画面の銘柄名はNavigationLinkのボタンになっている。
        let whiskyLink = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Year")
        ).firstMatch
        XCTAssertTrue(whiskyLink.waitForExistence(timeout: 5), "銘柄への導線が無い")
        whiskyLink.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(
            app.navigationBars["Whisky"].waitForExistence(timeout: 10),
            "銘柄ページに遷移しない"
        )
        sleep(2)
        capture("03-whisky")

        goHome()

        // --- 記録の作成 ---
        app.buttons["New check-in"].tap()
        XCTAssertTrue(app.navigationBars["New check-in"].waitForExistence(timeout: 10))
        sleep(1)
        capture("04-editor")
        app.buttons["Cancel"].tap()

        // --- マイページ（統計） ---
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 10))
        app.navigationBars["Home"].buttons["My page"].tap()
        XCTAssertTrue(app.navigationBars["My page"].waitForExistence(timeout: 10))
        sleep(2)
        capture("05-mypage")
    }

    /// ホームに戻るまで戻るボタンを押す。階層の深さを気にせず済むように。
    private func goHome() {
        for _ in 0..<4 {
            if app.navigationBars["Home"].exists { return }
            let back = app.navigationBars.buttons.element(boundBy: 0)
            guard back.exists else { return }
            back.tap()
            sleep(1)
        }
    }

    private func logIn() {
        let email = app.textFields["Email"]
        email.tap()
        email.typeText("test@example.com")
        let password = app.secureTextFields["Password"]
        password.tap()
        password.typeText("test")
        app.buttons["Log in"].tap()
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
