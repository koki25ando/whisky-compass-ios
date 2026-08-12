import XCTest

/// 実機・シミュレータ上で主要な画面が出ることを確認するスモークテスト。
///
/// **ローカルのDjango（localhost:8000）が起動している前提**。
/// バックエンドを立てずに実行すると通信エラーで落ちる。
/// 起動方法は README の「ローカルでの動かし方」を参照。
final class SmokeUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // 年齢確認は初回起動時にしか出ない。既存のテストは本題ではないので飛ばす
        // （年齢確認そのものは AgeGateUITests で検証する）。
        app.launchArguments = ["-uitest-skip-age-gate"]
        app.launch()
    }

    /// ログイン → ホーム → 記録の詳細 → 銘柄ページ、と辿れること。
    func testLogInAndBrowse() throws {
        capture("01-launch")

        // 既にログイン済みならログイン画面は出ない。
        if app.textFields["Email"].waitForExistence(timeout: 10) {
            logIn()
        }

        XCTAssertTrue(
            app.navigationBars["Home"].waitForExistence(timeout: 20),
            "ログイン後にホームが出ない"
        )
        capture("02-home")

        // フィードの1枚目のカードを開く。デモ記録が入っている前提。
        let firstCard = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Year")
        ).firstMatch
        guard firstCard.waitForExistence(timeout: 10) else {
            XCTFail("フィードに記録が無い。seed_whiskies とデモ記録の投入を確認すること")
            return
        }
        firstCard.tap()

        XCTAssertTrue(
            app.navigationBars["Check-in"].waitForExistence(timeout: 10),
            "詳細画面が開かない"
        )
        capture("03-detail")

        // 銘柄名をタップして銘柄ページへ。
        app.staticTexts.element(boundBy: 0).tap()
        if app.navigationBars["Whisky"].waitForExistence(timeout: 10) {
            capture("04-whisky")
        }
    }

    /// マイページ（統計・アカウント削除の導線）が開くこと。
    func testMyPage() throws {
        if app.textFields["Email"].waitForExistence(timeout: 10) {
            logIn()
        }
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 20))

        app.navigationBars["Home"].buttons["My page"].tap()
        XCTAssertTrue(
            app.navigationBars["My page"].waitForExistence(timeout: 10),
            "マイページが開かない"
        )
        // Google Play も App Store も必須にしている導線。消さないこと。
        XCTAssertTrue(
            app.buttons["Delete account"].waitForExistence(timeout: 5),
            "アカウント削除の導線が無い"
        )
        capture("05-mypage")
    }

    /// 新規作成画面が開き、フレーバーが既定でオフであること。
    func testEditorOpensWithFlavorsOff() throws {
        if app.textFields["Email"].waitForExistence(timeout: 10) {
            logIn()
        }
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 20))

        app.buttons["New check-in"].tap()
        XCTAssertTrue(
            app.navigationBars["New check-in"].waitForExistence(timeout: 10),
            "作成画面が開かない"
        )
        capture("06-editor")

        // 触っていないスライダーの初期値を保存しないための既定オフ。
        let toggle = app.switches["Record a flavor profile"]
        if toggle.waitForExistence(timeout: 5) {
            XCTAssertEqual(toggle.value as? String, "0", "フレーバーが既定でオンになっている")
        }
    }

    // MARK: - 補助

    private func logIn() {
        let email = app.textFields["Email"]
        email.tap()
        email.typeText("test@example.com")

        let password = app.secureTextFields["Password"]
        password.tap()
        password.typeText("test")

        app.buttons["Log in"].tap()
    }

    /// スクリーンショットをテスト結果に添付する（xcresultから取り出せる）。
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}


/// 法定飲酒年齢の確認。アルコールを扱うアプリとして審査で必ず見られる導線。
final class AgeGateUITests: XCTestCase {

    /// 「未成年」を選んだら、そこから先に進めないこと。
    func testUnderageUserIsBlocked() throws {
        let app = XCUIApplication()
        // 起動引数を付けない＝年齢確認が出る状態。
        app.launchArguments = ["-uitest-reset-age-gate"]
        app.launch()

        let confirm = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "I am ")
        ).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "年齢確認が表示されない")

        let decline = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "I am under")
        ).firstMatch
        XCTAssertTrue(decline.exists, "未成年を選ぶ導線が無い")
        decline.tap()

        // 先に進む手段が残っていないこと。
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "Come back")
            ).firstMatch.waitForExistence(timeout: 5),
            "未成年と答えたのにブロックされていない"
        )
        XCTAssertFalse(app.textFields["Email"].exists, "ログイン画面に到達できてしまっている")
    }

    /// 確認すればログイン画面に進めること。
    func testConfirmingAgeLetsYouThrough() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset-age-gate"]
        app.launch()

        let confirm = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "I am ")
        ).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        confirm.tap()

        XCTAssertTrue(
            app.textFields["Email"].waitForExistence(timeout: 10)
                || app.navigationBars["Home"].waitForExistence(timeout: 10),
            "年齢確認後に先へ進めない"
        )
    }
}
