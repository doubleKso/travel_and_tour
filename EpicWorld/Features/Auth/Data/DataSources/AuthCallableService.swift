// Port of lib/features/auth/data/datasources/auth_callable_service.dart
import Foundation

/// Firebase HTTPS callable authentication functions used by the client app.
///
/// The functions service wraps requests in `{ data: ... }` and unwraps the
/// callable result before it reaches this class.
final class AuthCallableService {
    private let functions: CallableInvoking

    init(_ functions: CallableInvoking) {
        self.functions = functions
    }

    /// Sends a Firebase ID token through the Firebase callable protocol, which
    /// wraps this map as `{ "data": { "idToken": ... } }` on the wire.
    func googleSignIn(idToken: String) async throws -> AuthLoginResponse {
        // Never log the credential itself. The request shape and length are
        // enough to diagnose device-side callable failures safely.
        superPrint(
            "authGoogleSignin request: {data: {idToken: <redacted; "
                + "\(idToken.utf16.count) characters>}}"
        )
        do {
            let response = try await functions.call(
                F.functionsUrl(Endpoints.authGoogleSignin),
                ["idToken": idToken] as JSON
            )
            let payload = try ApiException.callablePayload(
                response,
                endpoint: Endpoints.authGoogleSignin
            )
            superPrint(
                "authGoogleSignin response: success; "
                    + "fields=\(payload.keys.joined(separator: ", "))"
            )
            return AuthLoginResponse.fromJson(payload)
        } catch let error as FunctionsException {
            superPrint(
                "authGoogleSignin response: FirebaseFunctionsException("
                    + "code=\(error.code), message=\(error.message ?? "null"), "
                    + "details=\(Dart.interpolate(error.details)))"
            )
            throw error
        }
    }

    /// Invokes `authRegisterAgent`. The API reference documents no payload.
    func registerAgent() async throws -> String {
        try await call(Endpoints.authRegisterAgent)
    }

    /// Creates a customer account and immediately returns its session.
    func signUp(
        fullName: String,
        username: String,
        email: String,
        password: String
    ) async throws -> AuthLoginResponse {
        try await callSession(
            endpoint: Endpoints.authSignup,
            data: [
                "name": fullName,
                "username": username,
                "email": email,
                "password": password,
            ]
        )
    }

    /// Confirms the six-digit email code sent during sign-up.
    func verifyEmailOtp(userId: String, code: String) async throws -> Bool {
        try await callOk(Endpoints.authVerifyOtp, ["userId": userId, "code": code])
    }

    /// Sends a replacement email verification code.
    func resendEmailOtp(userId: String, email: String) async throws -> Bool {
        try await callOk(Endpoints.authResendOtp, ["userId": userId, "email": email])
    }

    /// Signs in with email and password through `authSignin`.
    func signIn(email: String, password: String) async throws -> AuthLoginResponse {
        try await callSession(
            endpoint: Endpoints.authSignin,
            data: ["email": email, "password": password]
        )
    }

    /// Answers the two-step checkpoint with the emailed code. On success the
    /// backend issues the session `authSignin` withheld.
    func verifyLoginOtp(userId: String, code: String) async throws -> AuthLoginResponse {
        try await callSession(
            endpoint: Endpoints.authVerifyLoginOtp,
            data: ["userId": userId, "code": code]
        )
    }

    /// Emails a replacement two-step sign-in code.
    func resendLoginOtp(userId: String) async throws -> Bool {
        try await callOk(Endpoints.authResendLoginOtp, ["userId": userId])
    }

    /// Ends the session server-side. The documented payload is empty, but this
    /// backend identifies a session by the access token in the body everywhere
    /// else, so the token is sent first and an empty body is the fallback for
    /// deployments that reject unknown fields.
    func signOut(accessToken: String) async throws -> Bool {
        if !accessToken.isEmpty {
            do {
                return try await callOk(Endpoints.authSignout, ["accessToken": accessToken])
            } catch {
                superPrint("authSignout with token failed: \(error)")
            }
        }
        return try await callOk(Endpoints.authSignout, [:])
    }

    /// Changes the signed-in user's password through `authChangePassword`.
    func changePassword(
        accessToken: String,
        currentPassword: String,
        newPassword: String
    ) async throws -> Bool {
        let result = try await functions.call(
            F.functionsUrl(Endpoints.authChangePassword),
            [
                "accessToken": accessToken,
                "currentPassword": currentPassword,
                "newPassword": newPassword,
            ] as JSON
        )
        let payload = try ApiException.callablePayload(
            result,
            endpoint: Endpoints.authChangePassword
        )
        return Dart.bool(payload["ok"]) == true
    }

    /// Emails a password reset code to `email`.
    func requestPasswordOtp(email: String) async throws -> Bool {
        try await callOk(Endpoints.authRequestPasswordOtp, ["email": email])
    }

    /// Sets a new password for `email` with the emailed reset code.
    func resetPasswordWithOtp(email: String, code: String, newPassword: String) async throws -> Bool {
        try await callOk(Endpoints.authResetPasswordWithOtp, [
            "email": email,
            "code": code,
            "newPassword": newPassword,
        ])
    }

    /// Exchanges a persisted refresh token and session ID for a fresh session.
    func refresh(refreshToken: String, sessionId: String) async throws -> AuthRefreshResponse {
        let result = try await functions.call(
            F.functionsUrl(Endpoints.authRefresh),
            ["refreshToken": refreshToken, "sessionId": sessionId] as JSON
        )
        let payload = try ApiException.callablePayload(
            result,
            endpoint: Endpoints.authRefresh
        )
        return AuthRefreshResponse.fromJson(payload)
    }

    /// Uploads a base64-encoded avatar and returns its hosted URL.
    func uploadAvatar(accessToken: String, data: String, contentType: String) async throws -> String {
        let result = try await functions.call(
            F.functionsUrl(Endpoints.authUploadAvatar),
            [
                "accessToken": accessToken,
                "data": data,
                "contentType": contentType,
            ] as JSON
        )
        let payload = try ApiException.callablePayload(
            result,
            endpoint: Endpoints.authUploadAvatar
        )
        let url = Dart.str(payload["url"]) ?? ""
        if url.isEmpty {
            throw FormatException("Avatar upload did not return a URL.")
        }
        return url
    }

    /// Updates the signed-in user's name and avatar URL through `dcExec`.
    func updateMyProfile(
        accessToken: String,
        id: String,
        name: String,
        avatarUrl: String
    ) async throws -> Bool {
        let result = try await functions.call(
            F.functionsUrl(Endpoints.dcExec),
            [
                "operation": "UpdateMyProfile",
                "variables": ["id": id, "name": name, "avatarUrl": avatarUrl],
                "accessToken": accessToken,
            ] as JSON
        )
        let payload = try ApiException.callablePayload(
            result,
            endpoint: "UpdateMyProfile"
        )
        return payload.keys.contains("appUser_update")
    }

    private func callSession(endpoint: String, data: JSON) async throws -> AuthLoginResponse {
        let result = try await functions.call(F.functionsUrl(endpoint), data)
        let payload = try ApiException.callablePayload(
            result,
            endpoint: endpoint
        )
        // Field names only — never the tokens. Enough to tell a session apart
        // from a two-step challenge when diagnosing a sign-in on a device.
        superPrint("\(endpoint) response: fields=\(payload.keys.joined(separator: ", "))")
        return AuthLoginResponse.fromJson(payload)
    }

    /// Validates a persisted access token and returns the latest user profile.
    func me(accessToken: String) async throws -> AuthUserDto {
        let result = try await functions.call(
            F.functionsUrl(Endpoints.authMe),
            ["accessToken": accessToken] as JSON
        )
        let payload = try ApiException.callablePayload(
            result,
            endpoint: Endpoints.authMe
        )
        return AuthLoginResponse.userFromJson(payload["user"]).copyWith(token: accessToken)
    }

    private func call(_ endpoint: String, _ data: JSON? = nil) async throws -> String {
        let result = try await functions.call(F.functionsUrl(endpoint), data)
        if let text = Dart.unwrap(result) as? String { return text }
        if Dart.isMap(result) {
            let payload = try ApiException.callablePayload(
                result,
                endpoint: endpoint
            )
            let value = Dart.unwrap(payload["value"])
                ?? Dart.unwrap(payload["message"])
                ?? Dart.unwrap(payload["result"])
            if let text = value as? String { return text }
        }
        throw FormatException("Unexpected result returned by \(endpoint).")
    }

    private func callOk(_ endpoint: String, _ data: JSON) async throws -> Bool {
        let result = try await functions.call(F.functionsUrl(endpoint), data)
        let payload = try ApiException.callablePayload(
            result,
            endpoint: endpoint
        )
        return Dart.bool(payload["ok"]) == true
    }
}
