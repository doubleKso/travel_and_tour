// Port of lib/features/auth/domain/usecases/sign_in_with_google_use_case.dart
import Foundation

/// Exchanges a Google-issued ID token for an app session.
final class SignInWithGoogleUseCase: UseCase {
    private let repository: AuthRepository

    init(_ repository: AuthRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: SignInWithGoogleParams) async -> AppResult<AuthUser> {
        await repository.signInWithGoogle(idToken: params.idToken)
    }
}

/// Dart record `({String idToken})` — a struct, as Swift has no single-element
/// labelled tuple.
struct SignInWithGoogleParams {
    let idToken: String
}
