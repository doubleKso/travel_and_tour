// Port of lib/features/auth/domain/usecases/restore_session_use_case.dart
import Foundation

/// Rebuilds the signed-in user from the session persisted on this device, if
/// any.
final class RestoreSessionUseCase: SyncUseCase {
    private let repository: AuthRepository

    init(_ repository: AuthRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: NoParams) -> AppResult<AuthUser?> {
        .success(repository.restoreSession())
    }
}
