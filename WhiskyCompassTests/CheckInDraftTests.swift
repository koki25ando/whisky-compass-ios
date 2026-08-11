import XCTest
@testable import WhiskyCompass

final class FlavorAxisTests: XCTestCase {

    func testAxesMatchTheServerContract() {
        // tastings/services.py の FLAVOR_AXES と順序まで一致していること。
        // ズレるとレーダーの軸が入れ替わり、データの意味が変わる。
        XCTAssertEqual(
            flavorAxes.map(\.key),
            ["smoky", "sweet", "fruity", "woody", "rich", "floral"]
        )
    }

    func testFlavorsAreOffByDefault() {
        // 触っていないスライダーの初期値を保存すると、フレーバーデータが汚れる。
        XCTAssertFalse(CheckInDraft().recordFlavors)
    }

    func testPhotoLimitMatchesTheServer() {
        XCTAssertEqual(maxPhotosPerCheckIn, 5)
    }
}

final class APIErrorTests: XCTestCase {

    func testDecodesFieldErrorsFromDRF() {
        let body = Data(#"{"password": ["That password is incorrect."]}"#.utf8)
        let error = APIError.from(status: 400, body: body)
        XCTAssertEqual(error.fieldErrors["password"], "That password is incorrect.")
    }

    func testUnauthorizedIsRecognised() {
        guard case .unauthorized = APIError.from(status: 401, body: Data()) else {
            return XCTFail("expected .unauthorized")
        }
    }

    func testNotFoundIsRecognised() {
        // 他人の記録への更新・削除はサーバーが404を返す（403ではない）。
        guard case .notFound = APIError.from(status: 404, body: Data()) else {
            return XCTFail("expected .notFound")
        }
    }

    func testThrottledResponseExplainsTheWait() {
        let error = APIError.from(status: 429, body: Data())
        XCTAssertTrue(error.message.lowercased().contains("too many"), error.message)
    }
}

final class MultipartTests: XCTestCase {

    func testRepeatedNamesBecomeAnArray() {
        // 同名パートの繰り返しでDRFのListFieldが配列として受ける。
        let parts: [MultipartPart] = [
            .text("photos", "a"),
            .text("photos", "b"),
        ]
        let body = MultipartPart.body(parts: parts, boundary: "X")
        let text = String(decoding: body, as: UTF8.self)
        XCTAssertEqual(text.components(separatedBy: "name=\"photos\"").count - 1, 2)
        XCTAssertTrue(text.hasSuffix("--X--\r\n"))
    }

    func testFilePartCarriesFilenameAndContentType() {
        let body = MultipartPart.body(
            parts: [.jpeg("photos", filename: "photo_0.jpg", data: Data([0xFF, 0xD8]))],
            boundary: "X"
        )
        let text = String(decoding: body, as: UTF8.self)
        XCTAssertTrue(text.contains("filename=\"photo_0.jpg\""))
        XCTAssertTrue(text.contains("Content-Type: image/jpeg"))
    }
}
