// Port of lib/features/auth/domain/usecases/login_use_case.dart
import Foundation

/// Signs in with email and password. An account with two-factor authentication
/// on comes back as a challenge instead of a session.
final class LoginUseCase: UseCase {
    private let repository: AuthRepository

    init(_ repository: AuthRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: LoginParams) async -> AppResult<SignInOutcome> {
        await repository.login(username: params.username, password: params.password)
    }
}

typealias LoginParams = (username: String, password: String)
