// Port of lib/features/auth/domain/usecases/get_current_user_use_case.dart
import Foundation

/// Fetches the signed-in profile (`authMe`) for a live access token.
final class GetCurrentUserUseCase: UseCase {
    private let repository: AuthRepository

    init(_ repository: AuthRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: GetCurrentUserParams) async -> AppResult<AuthUser> {
        await repository.getCurrentUser(accessToken: params.accessToken)
    }
}

/// Dart record `({String accessToken})`. Swift has no single-element labelled
/// tuple, so the one-field record is a struct with the same field name.
struct GetCurrentUserParams {
    let accessToken: String
}
