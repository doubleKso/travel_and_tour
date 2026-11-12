// Port of lib/features/auth/presentation/providers/auth_providers.dart
import Foundation

extension AppContainer {
    /// The session. Read state with `container.authNotifier.state`, call
    /// actions with `container.authNotifier.login(…)`.
    var authNotifier: AuthNotifier {
        provide {
            AuthNotifier(
                restoreSession: restoreSessionUseCase,
                getCurrentUser: getCurrentUserUseCase,
                refreshSession: refreshSessionUseCase,
                login: loginUseCase,
                verifyLoginOtp: verifyLoginOtpUseCase,
                resendLoginOtp: resendLoginOtpUseCase,
                signInWithGoogle: signInWithGoogleUseCase,
                register: registerUseCase,
                verifyEmailOtp: verifyEmailOtpUseCase,
                resendEmailOtp: resendEmailOtpUseCase,
                requestOtp: requestOtpUseCase,
                requestPasswordOtp: requestPasswordOtpUseCase,
                resetPasswordWithOtp: resetPasswordWithOtpUseCase,
                changePassword: changePasswordUseCase,
                uploadAvatar: uploadAvatarUseCase,
                updateProfile: updateProfileUseCase,
                logout: logoutUseCase
            )
        }
    }

    /// Convenience for views that only care whether someone is signed in.
    var isAuthenticated: Bool { authNotifier.state.isAuthenticated }
}
