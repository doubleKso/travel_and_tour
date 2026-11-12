import Foundation
@testable import EpicWorld

/// Shared fakes for the auth tests — the Swift side of the Dart tests'
/// `Fake implements FirebaseFunctions` callables and of
/// test/helpers/notifiers.dart's `authNotifierFor`.
///
/// Namespaced so it cannot collide with another feature's port of the shared
/// Dart test helpers.
enum AuthTestSupport {
    /// Builds the notifier exactly as `container.authNotifier` does, but over a
    /// fake repository (Dart `authNotifierFor(repository)`).
    @MainActor
    static func authNotifierFor(_ repository: AuthRepository) -> AuthNotifier {
        AuthNotifier(
            restoreSession: RestoreSessionUseCase(repository),
            getCurrentUser: GetCurrentUserUseCase(repository),
            refreshSession: RefreshSessionUseCase(repository),
            login: LoginUseCase(repository),
            verifyLoginOtp: VerifyLoginOtpUseCase(repository),
            resendLoginOtp: ResendLoginOtpUseCase(repository),
            signInWithGoogle: SignInWithGoogleUseCase(repository),
            register: RegisterUseCase(repository),
            verifyEmailOtp: VerifyEmailOtpUseCase(repository),
            resendEmailOtp: ResendEmailOtpUseCase(repository),
            requestOtp: RequestOtpUseCase(repository),
            requestPasswordOtp: RequestPasswordOtpUseCase(repository),
            resetPasswordWithOtp: ResetPasswordWithOtpUseCase(repository),
            changePassword: ChangePasswordUseCase(repository),
            uploadAvatar: UploadAvatarUseCase(repository),
            updateProfile: UpdateProfileUseCase(repository),
            logout: LogoutUseCase(repository)
        )
    }

    /// A REST client for services the tests never let reach the network
    /// (Dart `AuthRemoteService(Dio())`).
    static func unusedHTTPClient() -> HTTPClient {
        HTTPClient(baseURL: "", accessToken: { "" }, languageCode: { "en" })
    }

    /// `AuthRepositoryImpl` over a fake callable client.
    static func repository(_ functions: CallableInvoking) -> AuthRepositoryImpl {
        AuthRepositoryImpl(
            AuthRemoteService(unusedHTTPClient()),
            AuthMockService(),
            AuthCallableService(functions)
        )
    }

    /// An unsigned JWT whose payload is `claims`. The client only reads it.
    static func jwt(_ claims: JSON, header: JSON = ["alg": "RS256", "typ": "JWT"], signature: String = "signature") -> String {
        "\(segment(header)).\(segment(claims)).\(signature)"
    }

    private static func segment(_ value: JSON) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: value)) ?? Data()
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// A Firebase callable client that records every request — the Dart tests'
/// `_Functions` / `_Callable` fakes.
final class FakeAuthFunctions: CallableInvoking {
    /// The last URL called (`functions.url`).
    private(set) var url: String?
    /// Every request body, in order (`callable.requests`).
    private(set) var requests: [Any?] = []
    /// What each call answers with, unless `responder` is set.
    var response: Any?
    /// Thrown by every call when set.
    var error: FunctionsException?
    /// Fails only the first call, as a deployment rejecting an unknown field.
    var failFirst = false
    /// Per-URL answers.
    var responder: ((String) -> Any?)?

    init(response: Any? = nil) {
        self.response = response
    }

    func call(_ url: String, _ data: Any?, timeout: TimeInterval?) async throws -> Any? {
        self.url = url
        requests.append(data)
        if failFirst && requests.count == 1 {
            throw FunctionsException(code: "invalid-argument", message: "Unexpected field: accessToken")
        }
        if let error { throw error }
        if let responder { return responder(url) }
        return response
    }

    /// The request at `index` as a flat string map, for equality checks.
    func request(_ index: Int) -> [String: String]? {
        guard requests.indices.contains(index) else { return nil }
        return requests[index] as? [String: String]
    }
}

/// An `AuthRepository` whose every member is unimplemented — the Swift side of
/// the Dart fakes' `throw UnimplementedError()` / `noSuchMethod`. Test fakes
/// subclass it and override only what they exercise.
class UnimplementedAuthRepository: AuthRepository {
    func unimplemented<T>(_ name: String = #function) -> AppResult<T> {
        .failure(.unexpected("UnimplementedError: \(name)"))
    }

    func restoreSession() -> AuthUser? { nil }
    func getCurrentUser(accessToken: String) async -> AppResult<AuthUser> { unimplemented() }
    func refreshSession() async -> AppResult<AuthUser> { unimplemented() }
    func login(username: String, password: String) async -> AppResult<SignInOutcome> { unimplemented() }
    func verifyLoginOtp(userId: String, code: String) async -> AppResult<AuthUser> { unimplemented() }
    func resendLoginOtp(userId: String) async -> AppResult<Bool> { unimplemented() }
    func signInWithGoogle(idToken: String) async -> AppResult<AuthUser> { unimplemented() }
    func register(fullName: String, username: String, email: String, password: String) async -> AppResult<PendingEmailVerification> {
        unimplemented()
    }
    func verifyEmailOtp(pending: PendingEmailVerification, code: String) async -> AppResult<AuthUser> { unimplemented() }
    func resendEmailOtp(userId: String, email: String) async -> AppResult<Bool> { unimplemented() }
    func requestOtp(_ phone: String) async -> AppResult<Bool> { unimplemented() }
    func requestPasswordOtp(email: String) async -> AppResult<Bool> { unimplemented() }
    func resetPasswordWithOtp(email: String, code: String, newPassword: String) async -> AppResult<Bool> { unimplemented() }
    func changePassword(accessToken: String, current: String, next: String) async -> AppResult<Bool> { unimplemented() }
    func uploadAvatar(accessToken: String, data: String, contentType: String) async -> AppResult<String> { unimplemented() }
    func updateProfile(accessToken: String, id: String, name: String, avatarUrl: String) async -> AppResult<AuthUser> {
        unimplemented()
    }
    func logout() async {}
}
