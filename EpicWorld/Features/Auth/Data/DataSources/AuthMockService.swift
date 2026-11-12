// Port of lib/features/auth/data/datasources/auth_mock_service.dart
import Foundation

/// Stands in for `AuthRemoteService` until the auth API is live.
///
/// It keeps the validation rules the prototype shipped with, so the UX is
/// identical whichever service the repository picks.
///
/// Dart throws bare strings here; Swift throws `Exception(message)`, whose
/// `Exception: ` prefix `FailureMapper` strips, so the failure message is the
/// same text.
final class AuthMockService {
    init() {}

    func login(username: String, password: String) async throws -> AuthUserDto {
        try? await Task.sleep(for: Duration(milliseconds: 900))
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || password.count < 4 {
            throw Exception("Please enter a valid email and password.")
        }
        let id = trimmed
        let name = id.contains("@") ? (id.components(separatedBy: "@").first ?? id) : id
        return AuthUserDto(
            id: id,
            userName: name,
            email: id.contains("@") ? id : "\(id)@gmail.com",
            displayName: name,
            points: 3450,
            token: "mock-token-\(name)"
        )
    }

    func register(
        fullName: String,
        username: String,
        email: String,
        password: String
    ) async throws -> AuthUserDto {
        try? await Task.sleep(for: Duration(milliseconds: 900))
        if fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || password.count < 4 {
            throw Exception("Please fill in all fields with valid details.")
        }
        return AuthUserDto(
            id: username.trimmingCharacters(in: .whitespacesAndNewlines),
            userName: username.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            displayName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
            points: 0,
            token: "mock-token-\(username.trimmingCharacters(in: .whitespacesAndNewlines))"
        )
    }

    func requestOtp(_ phone: String) async throws -> Bool {
        try? await Task.sleep(for: Duration(milliseconds: 700))
        return true
    }

    func changePassword(current: String, next: String) async throws -> Bool {
        try? await Task.sleep(for: Duration(milliseconds: 700))
        if current.count < 4 { throw Exception("Your current password is incorrect.") }
        if next.count < 6 { throw Exception("New password must be at least 6 characters.") }
        return true
    }
}
