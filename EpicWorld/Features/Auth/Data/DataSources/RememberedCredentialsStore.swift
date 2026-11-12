// Port of lib/features/auth/data/datasources/remembered_credentials_store.dart
import Foundation

/// Credentials saved only after the user opts in with "Remember me".
///
/// They live in the iOS Keychain (the `flutter_secure_storage` layout, so the
/// native build reads what the Flutter build saved) rather than alongside
/// regular app preferences.
struct RememberedCredentials: Equatable {
    let email: String
    let password: String

    init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

/// Keychain reads and writes are synchronous and never throw here, so the
/// Dart `Future`s become plain calls; a failed write simply leaves nothing
/// remembered, which the sign-in page already tolerates.
enum RememberedCredentialsStore {
    /// `const FlutterSecureStorage()` — swappable for tests.
    static var storage = KeychainStore()

    static func read() -> RememberedCredentials? {
        let email = storage.read(AppConsts.keyRememberedEmail) ?? ""
        let password = storage.read(AppConsts.keyRememberedPassword) ?? ""
        if email.isEmpty || password.isEmpty { return nil }
        return RememberedCredentials(email: email, password: password)
    }

    static func save(email: String, password: String) {
        storage.write(AppConsts.keyRememberedEmail, email)
        storage.write(AppConsts.keyRememberedPassword, password)
    }

    static func clear() {
        storage.delete(AppConsts.keyRememberedEmail)
        storage.delete(AppConsts.keyRememberedPassword)
    }
}
