import Foundation
import Security

/// アクセス／リフレッシュトークンの保管。
///
/// iOSではKeychainが標準の保管先で、Androidで DataStore + Keystore の組み合わせに
/// 相当する。`kSecAttrAccessibleAfterFirstUnlock` にしているのは、
/// 端末再起動後にユーザーが一度解錠すればバックグラウンドからも読めるようにするため
/// （常時読める `Always` 系は使わない）。
actor TokenStore {

    private let service = "app.whiskycompass.tokens"
    private enum Key: String {
        case access
        case refresh
    }

    var hasSession: Bool {
        read(.refresh) != nil
    }

    func accessToken() -> String? { read(.access) }

    func refreshToken() -> String? { read(.refresh) }

    func save(access: String, refresh: String?) {
        write(.access, value: access)
        // リフレッシュトークンのローテーションで新しい値が来なかった場合は、
        // 既存のものを消さずに残す（消すと次回更新できなくなる）。
        if let refresh { write(.refresh, value: refresh) }
    }

    func clear() {
        for key in [Key.access, Key.refresh] {
            SecItemDelete(query(for: key) as CFDictionary)
        }
    }

    // MARK: - Keychain

    private func query(for key: Key) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
    }

    private func read(_ key: Key) -> String? {
        var query = query(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }
        return value
    }

    private func write(_ key: Key, value: String) {
        // 既存があれば消してから入れる。SecItemUpdate と書き分けるより短く、
        // トークンの保存頻度なら性能上の問題にならない。
        SecItemDelete(query(for: key) as CFDictionary)

        var attributes = query(for: key)
        attributes[kSecValueData as String] = Data(value.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }
}
