// Port of lib/features/auth/data/datasources/auth_remote_service.dart
import Foundation

/// Talks HTTP. No business rules, no caching, no `AppResult` — it returns the
/// parsed envelope and lets the repository decide what it means.
final class AuthRemoteService {
    private let dio: HTTPClient

    init(_ dio: HTTPClient) {
        self.dio = dio
    }

    func login(
        email: String,
        password: String,
        rememberMe: Bool = true
    ) async throws -> AppResponse<AuthLoginResponse?> {
        do {
            let response = try await dio.post(
                Endpoints.login,
                data: ["email": email, "password": password, "rememberMe": rememberMe] as JSON
            )
            return try parseLoginResponse(response.data)
        } catch let error as HTTPException {
            let body = error.responseData
            if Dart.isMap(body) { return try parseLoginResponse(body) }
            throw error
        }
    }

    private func parseLoginResponse(_ body: Any?) throws -> AppResponse<AuthLoginResponse?> {
        guard let map = Dart.map(body) else {
            throw FormatException("Invalid response body for auth login.")
        }
        return AppResponse.fromRawJson(map) { json in
            Dart.map(json).map(AuthLoginResponse.fromJson)
        }
    }

    func register(
        fullName: String,
        username: String,
        email: String,
        password: String
    ) async throws -> AppResponse<AuthRegisterResponse?> {
        do {
            let response = try await dio.post(
                Endpoints.authRegister,
                data: [
                    "fullName": fullName,
                    "userName": username,
                    "email": email,
                    "password": password,
                ] as JSON
            )
            return try parseRegisterResponse(response.data)
        } catch let error as HTTPException {
            let body = error.responseData
            if Dart.isMap(body) { return try parseRegisterResponse(body) }
            throw error
        }
    }

    private func parseRegisterResponse(_ body: Any?) throws -> AppResponse<AuthRegisterResponse?> {
        guard let map = Dart.map(body) else {
            throw FormatException("Invalid response body for auth registration.")
        }
        return AppResponse.fromRawJson(map) { json in
            Dart.map(json).map(AuthRegisterResponse.fromJson)
        }
    }

    func requestOtp(_ phone: String) async throws -> AppResponse<Bool> {
        let response = try await dio.post(
            Endpoints.requestOtp,
            data: ["phone": phone] as JSON
        )
        return AppResponse.fromRawJson(try Self.asMap(response.data)) { json in
            Dart.bool(json) == true
        }
    }

    func changePassword(current: String, next: String) async throws -> AppResponse<Bool> {
        let response = try await dio.post(
            Endpoints.changePassword,
            data: ["currentPassword": current, "newPassword": next] as JSON
        )
        return AppResponse.fromRawJson(try Self.asMap(response.data)) { json in
            Dart.bool(json) == true
        }
    }

    func updateProfile(name: String, email: String) async throws -> AppResponse<AuthUserDto?> {
        let response = try await dio.put(
            Endpoints.profile,
            data: ["displayName": name, "email": email] as JSON
        )
        return AppResponse.fromRawJson(try Self.asMap(response.data)) { json in
            Dart.map(json).map(AuthUserDto.fromJson)
        }
    }

    /// Dart's `response.data as Map<String, dynamic>` — a failed cast throws.
    private static func asMap(_ data: Any?) throws -> JSON {
        guard let map = Dart.map(data) else {
            throw Exception("type '\(type(of: data))' is not a subtype of type 'Map<String, dynamic>' in type cast")
        }
        return map
    }
}
