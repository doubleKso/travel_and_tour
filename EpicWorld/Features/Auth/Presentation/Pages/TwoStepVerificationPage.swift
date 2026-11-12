// Port of lib/features/auth/presentation/pages/two_step_verification_page.dart
import SwiftUI

/// TWO-STEP VERIFICATION — the checkpoint between a correct password and a
/// session, for accounts with two-factor authentication switched on.
///
/// `authSignin` issues no tokens for those accounts; it emails a six-digit
/// code and returns the ID it belongs to. This screen answers that challenge
/// with `authVerifyLoginOtp` (or asks for a new code with
/// `authResendLoginOtp`) and pops `true` once a session exists, leaving the
/// sign-in page that pushed it to decide where the user lands.
struct TwoStepVerificationPage: View {
    /// Account the emailed code belongs to.
    let userId: String

    /// Address the code went to, echoed back so the user knows where to look.
    let email: String

    init(userId: String, email: String) {
        self.userId = userId
        self.email = email
    }

    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router

    @State private var code = ""
    @State private var error: String?

    var body: some View {
        let loading = container.authNotifier.state.isLoading

        // Backing out is allowed: the sign-in page reads the popped result and
        // simply stays put when no session was issued.
        Scaffold(
            backgroundColor: AppColors.surface,
            appBar: {
                AppBar(
                    backgroundColor: AppColors.surface,
                    leading: {
                        Button {
                            backToSignIn()
                        } label: {
                            Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textPrimary)
                                .frame(width: 48, height: 48)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .allowsHitTesting(!loading)
                        .accessibilityLabel("Back to sign in")
                        .frame(width: 56)
                    },
                    actions: { EmptyView() },
                    title: { EmptyView() }
                )
            }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AppImage(AppAssets.brandLogo, height: 42, fit: .contain)
                    VGap(26)
                    Text("Two-step verification")
                        .textStyle(AppTypography.heading(30, color: AppColors.textPrimary, height: 1.15))
                    VGap(8)
                    Text(
                        email.isEmpty
                            ? "Enter the 6-digit code we emailed you to finish signing in."
                            : "Enter the 6-digit code we emailed to \(email) to finish signing in."
                    )
                    .textStyle(AppTypography.body(15.5, color: AppColors.textSecondary, height: 1.45))
                    if let error {
                        VGap(18)
                        OtpErrorMessage(message: error)
                    }
                    VGap(26)
                    Text("Verification code")
                        .textStyle(AppTypography.body(13, weight: .w600, color: AppColors.textSecondary))
                    VGap(8)
                    AuthCodeField(
                        text: $code,
                        enabled: !loading,
                        autofocus: true,
                        centered: true,
                        onSubmitted: { Task { await verify() } },
                        onChanged: { _ in
                            if error != nil { error = nil }
                        }
                    )
                    VGap(16)
                    Button {
                        Task { await verify() }
                    } label: {
                        if loading {
                            ProgressView()
                                .tint(Colors.white)
                                .frame(width: 22, height: 22)
                        } else {
                            Text("Verify & sign in")
                        }
                    }
                    .buttonStyle(ElevatedButtonStyle())
                    .disabled(loading)
                    VGap(10)
                    HStack(spacing: 0) {
                        Text("Didn't get the code?")
                            .textStyle(AppTypography.body(14, color: AppColors.textSecondary))
                        Button {
                            Task { await resend() }
                        } label: {
                            Text("Resend code")
                                .textStyle(AppTypography.body(14, weight: .w700, color: AppColors.primary))
                        }
                        .buttonStyle(TextButtonStyle())
                        .disabled(loading)
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: 460, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(24, 8, 24, 32)
            }
        }
    }

    /// The code check `_verify` runs before calling the API.
    static func codeError(_ code: String) -> String? {
        code.count != 6 ? "Enter the 6-digit code we emailed you." : nil
    }

    private func verify() async {
        let code = self.code.trimmingCharacters(in: .whitespacesAndNewlines)
        if let message = TwoStepVerificationPage.codeError(code) {
            error = message
            return
        }
        error = nil
        let ok = await container.authNotifier.verifyLoginOtp(userId: userId, code: code)
        if Task.isCancelled { return }
        if ok {
            // The sign-in page is still underneath and owns what happens next.
            router.pop(true)
            return
        }
        error = authError() ?? "The code is not valid."
    }

    private func resend() async {
        let ok = await container.authNotifier.resendLoginOtp(userId: userId)
        if Task.isCancelled { return }
        if ok {
            error = nil
            SnackBarCenter.shared.show("A new code has been sent.")
            return
        }
        error = authError() ?? "Unable to send a new code."
    }

    private func backToSignIn() {
        container.authNotifier.cancelTwoFactorSignIn()
        router.pop(false)
    }

    private func authError() -> String? {
        let error = container.authNotifier.state.error?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let error, !error.isEmpty else { return nil }
        return error
    }
}

private struct OtpErrorMessage: View {
    let message: String

    var body: some View {
        Text(message)
            .textStyle(AppTypography.body(14, weight: .w500, color: Color(0xFFE32222)))
            // EdgeInsets.symmetric(16, 14) plus the 1pt border.
            .padding(horizontal: 17, vertical: 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .boxDecoration(color: Color(0xFFFFF1F1), radius: 13, borderColor: Color(0xFFFFD7D7))
    }
}
