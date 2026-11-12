// Port of lib/features/auth/di/auth_module.dart
import Foundation

/// Dependency graph for auth: data sources → repository. UI state (the
/// session notifier) lives in `Presentation/Providers/AuthProviders.swift`.
///
/// Every dependency is a provider, so a test overrides one line
/// (`container.override("authRepository", with: FakeAuthRepository())`)
/// instead of reaching for a mocking framework.
extension AppContainer {
    var authRemoteService: AuthRemoteService {
        provide { AuthRemoteService(http) }
    }

    /// Firebase callable client for Google sign-in, agent registration, and
    /// email/password sign-in.
    var authCallableService: AuthCallableService {
        provide { AuthCallableService(functions) }
    }

    var authMockService: AuthMockService {
        provide { AuthMockService() }
    }

    var authRepository: AuthRepository {
        provide {
            AuthRepositoryImpl(
                authRemoteService,
                authMockService,
                authCallableService
            ) as AuthRepository
        }
    }

    // ---- Use cases ------------------------------------------------------------

    var changePasswordUseCase: ChangePasswordUseCase {
        provide { ChangePasswordUseCase(authRepository) }
    }

    var getCurrentUserUseCase: GetCurrentUserUseCase {
        provide { GetCurrentUserUseCase(authRepository) }
    }

    var loginUseCase: LoginUseCase {
        provide { LoginUseCase(authRepository) }
    }

    var logoutUseCase: LogoutUseCase {
        provide { LogoutUseCase(authRepository) }
    }

    var refreshSessionUseCase: RefreshSessionUseCase {
        provide { RefreshSessionUseCase(authRepository) }
    }

    var registerUseCase: RegisterUseCase {
        provide { RegisterUseCase(authRepository) }
    }

    var requestOtpUseCase: RequestOtpUseCase {
        provide { RequestOtpUseCase(authRepository) }
    }

    var requestPasswordOtpUseCase: RequestPasswordOtpUseCase {
        provide { RequestPasswordOtpUseCase(authRepository) }
    }

    var resendEmailOtpUseCase: ResendEmailOtpUseCase {
        provide { ResendEmailOtpUseCase(authRepository) }
    }

    var resendLoginOtpUseCase: ResendLoginOtpUseCase {
        provide { ResendLoginOtpUseCase(authRepository) }
    }

    var resetPasswordWithOtpUseCase: ResetPasswordWithOtpUseCase {
        provide { ResetPasswordWithOtpUseCase(authRepository) }
    }

    var restoreSessionUseCase: RestoreSessionUseCase {
        provide { RestoreSessionUseCase(authRepository) }
    }

    var signInWithGoogleUseCase: SignInWithGoogleUseCase {
        provide { SignInWithGoogleUseCase(authRepository) }
    }

    var updateProfileUseCase: UpdateProfileUseCase {
        provide { UpdateProfileUseCase(authRepository) }
    }

    var uploadAvatarUseCase: UploadAvatarUseCase {
        provide { UploadAvatarUseCase(authRepository) }
    }

    var verifyEmailOtpUseCase: VerifyEmailOtpUseCase {
        provide { VerifyEmailOtpUseCase(authRepository) }
    }

    var verifyLoginOtpUseCase: VerifyLoginOtpUseCase {
        provide { VerifyLoginOtpUseCase(authRepository) }
    }
}
