import Foundation
import Security

/// Keychain storage laid out exactly like `flutter_secure_storage` on iOS
/// (generic passwords, service `flutter_secure_storage_service`, account =
/// key, readable when unlocked), so the native build finds the session the
/// Flutter build saved.
struct KeychainStore {
    var service = "flutter_secure_storage_service"

    func read(_ key: String) -> String? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    func write(_ key: String, _ value: String) -> Bool {
        delete(key)
        var attributes = baseQuery(key)
        attributes[kSecValueData as String] = Data(value.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    func delete(_ key: String) -> Bool {
        let status = SecItemDelete(baseQuery(key) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private func baseQuery(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}

/// Encrypted, in-memory-cached storage for the active backend session — the
/// port of `app_storage`'s `SecureSessionStore`.
///
/// The cache lets `HTTPClient` attach the bearer token synchronously, while
/// the source of truth remains the Keychain.
///
/// The signed-in profile lives here too, beside the tokens, so the two always
/// survive or disappear together. iOS keeps Keychain items after the app is
/// deleted but wipes its preferences — a profile kept in preferences came
/// back after a reinstall as a signed-in session with no account behind it.
enum SecureSessionStore {
    // Storage keys. Changing a value orphans every session already saved on a
    // device, so treat these as a persisted contract.
    private static let keyAccessToken = "auth_token"
    private static let keyRefreshToken = "refresh_token"
    private static let keySessionId = "session_id"
    private static let keyProfile = "session_profile"

    /// Swappable for tests.
    static var keychain = KeychainStore()

    private(set) static var accessToken = ""
    private(set) static var refreshToken = ""
    private(set) static var sessionId = ""

    /// The signed-in account as last saved, in its JSON form. Empty when none
    /// has been saved — including sessions saved before profiles moved here.
    private(set) static var profile: JSON = [:]

    /// Must run before the app creates its authenticated objects. Keychain
    /// reads are synchronous, so this is too (Dart: `await init()`).
    static func initialize() {
        accessToken = read(keyAccessToken)
        refreshToken = read(keyRefreshToken)
        sessionId = read(keySessionId)
        profile = decodeProfile(read(keyProfile))
    }

    static func save(
        accessToken: String? = nil,
        refreshToken: String? = nil,
        sessionId: String? = nil,
        profile: JSON? = nil
    ) {
        if let accessToken {
            self.accessToken = accessToken
            keychain.write(keyAccessToken, accessToken)
        }
        if let refreshToken {
            self.refreshToken = refreshToken
            keychain.write(keyRefreshToken, refreshToken)
        }
        if let sessionId {
            self.sessionId = sessionId
            keychain.write(keySessionId, sessionId)
        }
        if let profile {
            self.profile = profile
            keychain.write(keyProfile, jsonEncode(profile))
        }
    }

    static func clear() {
        accessToken = ""
        refreshToken = ""
        sessionId = ""
        profile = [:]
        keychain.delete(keyAccessToken)
        keychain.delete(keyRefreshToken)
        keychain.delete(keySessionId)
        keychain.delete(keyProfile)
    }

    /// Reads one key, treating a value that cannot be read as absent: that
    /// must start the app signed out, not stop it starting.
    private static func read(_ key: String) -> String {
        keychain.read(key) ?? ""
    }

    private static func decodeProfile(_ value: String) -> JSON {
        guard !value.isEmpty, let decoded = try? jsonDecode(value) else { return [:] }
        return Dart.map(decoded) ?? [:]
    }
}
