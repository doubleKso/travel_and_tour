// Port of lib/features/auth/domain/usecases/refresh_session_use_case.dart
import Foundation

/// Exchanges the persisted refresh token for a fresh session.
final class RefreshSessionUseCase: UseCase {
    private let repository: AuthRepository

    init(_ repository: AuthRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: NoParams) async -> AppResult<AuthUser> {
        await repository.refreshSession()
    }
}
