// Port of lib/features/auth/domain/usecases/upload_avatar_use_case.dart
import Foundation

/// Uploads a base64-encoded avatar image and returns its URL.
final class UploadAvatarUseCase: UseCase {
    private let repository: AuthRepository

    init(_ repository: AuthRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: UploadAvatarParams) async -> AppResult<String> {
        await repository.uploadAvatar(
            accessToken: params.accessToken,
            data: params.data,
            contentType: params.contentType
        )
    }
}

typealias UploadAvatarParams = (accessToken: String, data: String, contentType: String)
