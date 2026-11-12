// Port of lib/features/auth/domain/usecases/change_password_use_case.dart
import Foundation

/// Changes the signed-in user's password.
final class ChangePasswordUseCase: UseCase {
    private let repository: AuthRepository

    init(_ repository: AuthRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: ChangePasswordParams) async -> AppResult<Bool> {
        await repository.changePassword(
            accessToken: params.accessToken,
            current: params.current,
            next: params.next
        )
    }
}

typealias ChangePasswordParams = (accessToken: String, current: String, next: String)
