// Port of lib/features/auth/domain/usecases/update_profile_use_case.dart
import Foundation

/// Saves the signed-in user's name and avatar.
final class UpdateProfileUseCase: UseCase {
    private let repository: AuthRepository

    init(_ repository: AuthRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: UpdateProfileParams) async -> AppResult<AuthUser> {
        await repository.updateProfile(
            accessToken: params.accessToken,
            id: params.id,
            name: params.name,
            avatarUrl: params.avatarUrl
        )
    }
}

typealias UpdateProfileParams = (accessToken: String, id: String, name: String, avatarUrl: String)
