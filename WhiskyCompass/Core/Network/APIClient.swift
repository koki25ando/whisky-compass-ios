import Foundation

/// バックエンド（whisky-compass-web の /api/v1/）との通信。
///
/// 401を受けたらアクセストークンを一度だけ更新して再送する。Androidでは
/// OkHttpのAuthenticatorが担っていた役割を、ここでは`send`の中で明示的に行う。
/// 「一度だけ」を守らないと、リフレッシュも失効しているときに無限ループになる。
actor APIClient {

    static let shared = APIClient()

    /// シミュレータはMacのネットワークをそのまま使うので localhost で届く。
    /// （Androidのエミュレータは 10.0.2.2 への読み替えが必要だった）
    static var baseURL: URL {
        #if DEBUG
        return URL(string: "http://localhost:8000/")!
        #else
        return URL(string: "https://whiskycompass.app/")!
        #endif
    }

    let tokenStore = TokenStore()

    private let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        // 写真つきの記録はモバイル回線だと数秒かかる。既定値では取りこぼす。
        configuration.timeoutIntervalForRequest = 60
        return URLSession(configuration: configuration)
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    /// 認証を付けないパス。期限切れトークンを付けるとログイン自体が失敗する。
    private let publicPaths = ["api/v1/auth/token/", "api/v1/auth/signup/"]

    // MARK: - 公開API

    func get<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        try await send(request(path: path, method: "GET"), as: T.self)
    }

    /// カーソルページングの次ページ。`next`は絶対URLなのでそのまま使う。
    func getAbsolute<T: Decodable>(_ urlString: String, as type: T.Type) async throws -> T {
        guard let url = URL(string: urlString) else { throw APIError.unknown }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        return try await send(request, as: T.self)
    }

    @discardableResult
    /// 本文は `[String: Any]`。真偽値・数値をJSONの型のまま送るため
    /// （文字列にするとサーバー側の型変換に依存してしまう）。
    func postJSON<T: Decodable>(
        _ path: String,
        body: [String: Any],
        as type: T.Type
    ) async throws -> T {
        var request = self.request(path: path, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await send(request, as: T.self)
    }

    /// 応答本文を使わないPOST（アカウント削除など204が返るもの）。
    func postJSONIgnoringResponse(_ path: String, body: [String: Any]) async throws {
        var request = self.request(path: path, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await sendRaw(request)
    }

    func sendMultipart<T: Decodable>(
        _ path: String,
        method: String,
        parts: [MultipartPart],
        as type: T.Type
    ) async throws -> T {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = self.request(path: path, method: method)
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = MultipartPart.body(parts: parts, boundary: boundary)
        return try await send(request, as: T.self)
    }

    func delete(_ path: String) async throws {
        _ = try await sendRaw(request(path: path, method: "DELETE"))
    }

    // MARK: - 内部

    private func request(path: String, method: String) -> URLRequest {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent(path))
        request.httpMethod = method
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let data = try await sendRaw(request)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.unknown
        }
    }

    private func sendRaw(_ request: URLRequest, isRetry: Bool = false) async throws -> Data {
        var request = request
        let path = request.url?.path ?? ""
        let needsAuth = !publicPaths.contains { path.hasSuffix($0) || path.contains($0) }

        if needsAuth, let token = await tokenStore.accessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.offline
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }

        if http.statusCode == 401, needsAuth, !isRetry {
            // 一度だけトークンを更新して再送する。再度401ならリフレッシュ自体が無効。
            if await refreshAccessToken() {
                return try await sendRaw(request, isRetry: true)
            }
            await tokenStore.clear()
            throw APIError.unauthorized
        }

        guard (200..<300).contains(http.statusCode) else {
            throw APIError.from(status: http.statusCode, body: data)
        }
        return data
    }

    private func refreshAccessToken() async -> Bool {
        guard let refresh = await tokenStore.refreshToken() else { return false }

        var request = self.request(path: "api/v1/auth/token/refresh/", method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["refresh": refresh])

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let pair = try? decoder.decode(TokenPairDTO.self, from: data)
        else { return false }

        // ROTATE_REFRESH_TOKENS=True のため、新しいリフレッシュトークンも返る。
        await tokenStore.save(access: pair.access, refresh: pair.refresh)
        return true
    }
}
