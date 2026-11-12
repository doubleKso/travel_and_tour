// Port of lib/features/auth/data/datasources/google_auth_service.dart
import Foundation
import UIKit
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

/// Signs in with Google and exchanges that credential for a Firebase ID token.
///
/// `authGoogleSignin` expects the Firebase token returned by Identity Toolkit,
/// not the Google OAuth ID token used to obtain it. Firebase Auth performs the
/// `accounts:signInWithIdp` exchange with the current app's Firebase options.
enum GoogleAuthService {
    /// Dart `GoogleSignIn.instance.initialize(serverClientId: …)`, run once.
    /// The iOS client ID comes from the flavor's GoogleService-Info.plist, as
    /// the Flutter plugin reads it.
    private static let initialization: Void = {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: FirebaseApp.app()?.options.clientID ?? "",
            serverClientID: Env.googleWebClientId
        )
    }()

    private static var hasGoogleSession = false

    /// `FirebaseAuthException`'s error domain and its code-name key, spelled
    /// out so the check does not depend on how a Firebase release exports them.
    private static let firebaseAuthErrorDomain = "FIRAuthErrorDomain"
    private static let firebaseAuthErrorNameKey = "FIRAuthErrorUserInfoNameKey"

    /// Returns nil when the user closes the Google account picker.
    @MainActor
    static func getFirebaseIdToken() async throws -> String? {
        try ensureFirebaseConfigured()
        _ = initialization

        do {
            guard let presenter = UIApplication.shared.topViewController else {
                throw StateError("Google Sign-In could not find a screen to present from.")
            }
            let account = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            hasGoogleSession = true
            let googleIdToken = account.user.idToken?.tokenString
            guard let googleIdToken, !googleIdToken.isEmpty else {
                throw StateError(
                    "Google did not return an ID token. Verify the Web OAuth client ID "
                        + "and this Android app package/SHA certificate configuration."
                )
            }

            try validateIdTokenConfiguration(googleIdToken)

            let credential = GoogleAuthProvider.credential(
                withIDToken: googleIdToken,
                accessToken: account.user.accessToken.tokenString
            )
            let firebaseCredential = try await Auth.auth().signIn(with: credential)
            let firebaseIdToken = try await firebaseCredential.user.getIDToken(forcingRefresh: true)
            guard !firebaseIdToken.isEmpty else {
                throw StateError(
                    "Firebase did not return an ID token after Google Sign-In."
                )
            }

            try validateFirebaseIdTokenConfiguration(
                firebaseIdToken,
                projectId: FirebaseApp.app()?.options.projectID ?? ""
            )
            return firebaseIdToken
        } catch let error as NSError where error.domain == kGIDSignInErrorDomain {
            if error.code == GIDSignInError.Code.canceled.rawValue { return nil }
            // The Android-only `clientConfigurationError` branch has no iOS
            // counterpart: a misconfigured iOS client fails before this point.
            throw error
        } catch let error as NSError where error.domain == firebaseAuthErrorDomain {
            throw StateError(
                "Firebase could not exchange the Google credential "
                    + "(\(flutterFireCode(error))). Verify that Google is enabled in Firebase "
                    + "Authentication and that this app uses the matching Firebase project."
            )
        }
    }

    /// Clears the provider session so a later sign-in can choose another
    /// Google account after the app's own session has been logged out.
    @MainActor
    static func signOut() async throws {
        try ensureFirebaseConfigured()
        try Auth.auth().signOut()
        if hasGoogleSession {
            _ = initialization
            GIDSignIn.sharedInstance.signOut()
        }
        hasGoogleSession = false
    }

    /// Checks the public claims that tie a Google ID token to this client.
    ///
    /// This deliberately does not try to verify the JWT signature; that remains
    /// the backend's responsibility. It catches a wrong OAuth audience or a
    /// stale token before making a request that can only result in a 401.
    /// (`@visibleForTesting` in Dart.)
    static func validateIdTokenConfiguration(_ idToken: String, now: DateTime? = nil) throws {
        let claims = try decodeClaims(idToken, source: "Google")
        let issuer = Dart.str(claims["iss"])
        if issuer != "accounts.google.com" && issuer != "https://accounts.google.com" {
            throw StateError("Google returned an ID token with an invalid issuer.")
        }

        let audiences = audiencesOf(claims["aud"])
        if !audiences.contains(Env.googleWebClientId) {
            throw StateError(
                "Google ID token audience does not match the configured Web OAuth "
                    + "client ID (\(Env.googleWebClientId))."
            )
        }

        try validateExpiration(claims, source: "Google", now: now)

        #if DEBUG
        superPrint(
            "Google ID token configuration: issuer=\(issuer ?? "null"), "
                + "audience=\(Env.googleWebClientId)"
        )
        #endif
    }

    /// Checks that Identity Toolkit returned a Firebase token for this project.
    /// (`@visibleForTesting` in Dart.)
    static func validateFirebaseIdTokenConfiguration(
        _ idToken: String,
        projectId: String,
        now: DateTime? = nil
    ) throws {
        let claims = try decodeClaims(idToken, source: "Firebase")
        let expectedIssuer = "https://securetoken.google.com/\(projectId)"
        if Dart.str(claims["iss"]) != expectedIssuer {
            throw StateError("Firebase returned an ID token with an invalid issuer.")
        }

        let audiences = audiencesOf(claims["aud"])
        if !audiences.contains(projectId) {
            throw StateError(
                "Firebase ID token audience does not match project \(projectId)."
            )
        }

        try validateExpiration(claims, source: "Firebase", now: now)
    }

    // MARK: - Private

    /// `rawAudience is List ? {…} : {rawAudience?.toString() ?? ''}`.
    private static func audiencesOf(_ rawAudience: Any?) -> Set<String> {
        if let list = Dart.list(rawAudience) {
            return Set(list.map { Dart.interpolate($0) })
        }
        return [Dart.str(rawAudience) ?? ""]
    }

    private static func decodeClaims(_ idToken: String, source: String) throws -> JSON {
        let parts = idToken.components(separatedBy: ".")
        if parts.count != 3 {
            throw FormatException("\(source) returned a malformed ID token.")
        }

        // `base64Url.normalize` + `base64Url.decode` + `utf8.decode` + `jsonDecode`;
        // any failure along the way is a malformed token.
        guard let decoded = decodeSegment(parts[1]) else {
            throw FormatException("\(source) returned a malformed ID token.")
        }
        guard let claims = Dart.map(decoded) else {
            throw FormatException("\(source) returned a malformed ID token.")
        }
        return claims
    }

    private static func decodeSegment(_ segment: String) -> Any? {
        var base64 = segment
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder == 1 { return nil }
        if remainder > 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        guard let data = Data(base64Encoded: base64),
              let text = String(data: data, encoding: .utf8) else { return nil }
        return try? jsonDecode(text)
    }

    private static func validateExpiration(_ claims: JSON, source: String, now: DateTime?) throws {
        let rawExpiration = claims["exp"]
        let expirationSeconds = Dart.isNum(rawExpiration)
            ? Dart.int(rawExpiration)
            : Dart.parseInt(Dart.str(rawExpiration) ?? "")
        guard let expirationSeconds else {
            throw FormatException(
                "\(source) returned an ID token without an expiration time."
            )
        }
        let currentSeconds = (now ?? DateTime.now()).millisecondsSinceEpoch / 1000
        if expirationSeconds <= currentSeconds {
            throw StateError(
                "\(source) returned an expired ID token. Please try again."
            )
        }
    }

    /// FlutterFire's `FirebaseAuthException.code`: the iOS error name without
    /// its `ERROR_` prefix, lower-cased and hyphenated (`invalid-credential`).
    private static func flutterFireCode(_ error: NSError) -> String {
        guard let name = error.userInfo[firebaseAuthErrorNameKey] as? String else {
            return "unknown"
        }
        var code = name
        if code.hasPrefix("ERROR_") { code = String(code.dropFirst("ERROR_".count)) }
        return code.lowercased().replacingOccurrences(of: "_", with: "-")
    }

    /// `FirebaseAuth.instance` throws in Dart when no Firebase app exists;
    /// `Auth.auth()` would crash instead, so the same failure is raised here.
    private static func ensureFirebaseConfigured() throws {
        if FirebaseApp.app() == nil {
            throw StateError("No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()")
        }
    }
}
