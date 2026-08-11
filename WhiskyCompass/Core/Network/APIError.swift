import Foundation

/// APIのエラー。画面にそのまま出せる文言と、入力欄に紐づくエラーの両方を持つ。
enum APIError: Error {
    case offline
    case unauthorized
    case notFound
    case server
    /// DRFの `{"field": ["message"]}` 形式を解いたもの。
    case validation(fields: [String: String])
    case unknown

    /// 入力欄に紐づかないエラーとして画面上部に出す一文。
    var message: String {
        switch self {
        case .offline:
            return "Can't reach the server. Check your connection."
        case .unauthorized:
            return "Your session expired. Please log in again."
        case .notFound:
            return "That record no longer exists."
        case .server:
            return "Something went wrong on the server."
        case .validation(let fields):
            return fields.values.first ?? "Please check your input."
        case .unknown:
            return "Something went wrong."
        }
    }

    /// 入力欄ごとのエラー。フォームのどの欄に赤字を出すか決めるのに使う。
    var fieldErrors: [String: String] {
        if case .validation(let fields) = self { return fields }
        return [:]
    }

    /// HTTPステータスとレスポンスボディからエラーを組み立てる。
    static func from(status: Int, body: Data) -> APIError {
        switch status {
        case 401:
            return .unauthorized
        case 404:
            return .notFound
        case 400, 429:
            let fields = decodeFieldErrors(from: body)
            if status == 429 {
                return .validation(fields: fields.isEmpty
                    ? ["detail": "Too many attempts. Please wait a moment and try again."]
                    : fields)
            }
            return .validation(fields: fields)
        case 500...:
            return .server
        default:
            return .unknown
        }
    }

    /// `{"password": ["That password is incorrect."]}` のような形を平らにする。
    private static func decodeFieldErrors(from body: Data) -> [String: String] {
        guard let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            return [:]
        }
        var result: [String: String] = [:]
        for (key, value) in object {
            if let list = value as? [Any], let first = list.first {
                result[key] = String(describing: first)
            } else {
                result[key] = String(describing: value)
            }
        }
        return result
    }
}
