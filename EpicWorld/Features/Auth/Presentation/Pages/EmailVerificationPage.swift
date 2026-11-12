// Port of lib/features/auth/presentation/pages/email_verification_page.dart
import SwiftUI

/// Email OTP checkpoint displayed after email/password account registration.
struct EmailVerificationPage: View {
    let userId: String
    let email: String

    init(userId: String, email: String) {
        self.userId = userId
        self.email = email
    }

    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router

    @State private var code = ""
    @State private var verificationError: String?

    var body: some View {
        let loading = container.authNotifier.state.isLoading

        GeometryReader { proxy in
            // `MediaQuery.sizeOf(context).height` — the full screen height.
            let screenHeight = proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
            ScrollView {
                VStack(spacing: 0) {
                    AppImage(AppAssets.brandLogo, height: 48, fit: .contain)
                    VGap(screenHeight < 640 ? 48 : 76)
                    // CircleAvatar(radius: 29).
                    Icon(Icons.mail_outline_rounded, size: 29, color: AppColors.primary)
                        .frame(width: 58, height: 58)
                        .background(Circle().fill(Color(0xFFF0F7EE)))
                    VGap(26)
                    Text("Verify your email")
                        .textStyle(AppTypography.heading(30, color: AppColors.textPrimary))
                        .multilineTextAlignment(.center)
                    VGap(8)
                    sentToText
                        .multilineTextAlignment(.center)
                    if let verificationError {
                        VGap(18)
                        OtpErrorMessage(message: verificationError)
                        VGap(28)
                    } else {
                        VGap(30)
                    }
                    Text("Verification code")
                        .textStyle(AppTypography.body(13, weight: .w600, color: AppColors.textSecondary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    VGap(8)
                    AuthCodeField(
                        text: $code,
                        enabled: !loading,
                        autofocus: true,
                        centered: true,
                        onSubmitted: { Task { await verify() } },
                        onChanged: { _ in
                            if verificationError != nil { verificationError = nil }
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
                            Text("Verify email")
                        }
                    }
                    .buttonStyle(ElevatedButtonStyle())
                    .disabled(loading)
                    VGap(18)
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
                    VGap(14)
                    Button {
                        router.replaceAll([.login()])
                    } label: {
                        Text("Skip for now")
                            .textStyle(AppTypography.body(14, weight: .w700, color: AppColors.textPlaceholder))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(TextButtonStyle())
                    .disabled(loading)
                }
                .frame(maxWidth: 460)
                // ConstrainedBox(minHeight: maxHeight - 56) → Center → Column(center).
                .frame(maxWidth: .infinity, minHeight: max(0, proxy.size.height - 56))
                .padding(horizontal: 24, vertical: 28)
            }
        }
        .background(AppColors.surface.ignoresSafeArea())
    }

    /// `Text.rich(TextSpan(text: 'We sent a 6-digit code to ', children: [email]))`.
    private var sentToText: Text {
        Text("We sent a 6-digit code to ")
            .styled(AppTypography.body(16, color: AppColors.textSecondary))
            + Text(email)
            .styled(AppTypography.body(16, weight: .w700, color: AppColors.textPrimary))
    }

    /// The code check `_verify` runs before calling the API.
    static func codeError(_ code: String) -> String? {
        code.count != 6 ? "Enter the 6-digit verification code." : nil
    }

    private func verify() async {
        let code = self.code.trimmingCharacters(in: .whitespacesAndNewlines)
        if let error = EmailVerificationPage.codeError(code) {
            verificationError = error
            return
        }
        verificationError = nil
        let ok = await container.authNotifier.verifyEmailOtp(userId: userId, code: code)
        if Task.isCancelled { return }
        if ok {
            router.replaceAll([.mainShell])
            return
        }
        if let error = container.authNotifier.state.error?.trimmingCharacters(in: .whitespacesAndNewlines),
           !error.isEmpty {
            showMessage(error)
        }
    }

    private func resend() async {
        let ok = await container.authNotifier.resendEmailOtp(userId: userId, email: email)
        if Task.isCancelled { return }
        if ok {
            showMessage("A new verification code has been sent.")
            return
        }
        if let error = container.authNotifier.state.error?.trimmingCharacters(in: .whitespacesAndNewlines),
           !error.isEmpty {
            showMessage(error)
        }
    }

    private func showMessage(_ message: String) {
        SnackBarCenter.shared.show(message)
    }
}

private struct OtpErrorMessage: View {
    let message: String

    var body: some View {
        Text(message)
            .textStyle(AppTypography.body(14, weight: .w500, color: Color(0xFFE32222)))
            .multilineTextAlignment(.center)
            // EdgeInsets.symmetric(16, 14) plus the 1pt border.
            .padding(horizontal: 17, vertical: 15)
            .frame(maxWidth: .infinity)
            .boxDecoration(color: Color(0xFFFFF1F1), radius: 13, borderColor: Color(0xFFFFD7D7))
    }
}
