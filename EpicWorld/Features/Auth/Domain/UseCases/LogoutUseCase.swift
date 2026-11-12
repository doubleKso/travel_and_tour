// Port of lib/features/auth/domain/usecases/logout_use_case.dart
import Foundation

/// Ends the session and clears it from this device.
///
/// A failure while clearing the session propagates, exactly as it did when
/// the notifier called the repository directly.
final class LogoutUseCase: UseCase {
    private let repository: AuthRepository

    init(_ repository: AuthRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: NoParams) async -> AppResult<Void> {
        await repository.logout()
        return .success(())
    }
}
