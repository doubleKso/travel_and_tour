// Port of lib/features/auth/presentation/pages/login_page.dart
import SwiftUI
import UIKit

/// LOGIN — green hero header (logo + "Sign in") above a white sheet holding the
/// email / password form with a "Sign in" action.
struct LoginPage: View {
    /// When true, a successful customer sign-in just pops this screen (returning
    /// to the caller — e.g. the payment page) instead of unwinding to the app
    /// shell. The caller can then react to the now-authenticated state.
    let popOnSuccess: Bool

    init(popOnSuccess: Bool = false) {
        self.popOnSuccess = popOnSuccess
    }

    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router

    @State private var email = ""
    @State private var password = ""
    @State private var obscurePassword = true
    @State private var rememberMe = false

    /// Set when the user comes back from a completed password reset.
    @State private var passwordReset = false

    // Form validation results (`_formKey.currentState!.validate()`).
    @State private var emailError: String?
    @State private var passwordError: String?

    /// `initState` runs once; `.task` re-runs whenever the page reappears.
    @State private var didInitState = false

    var body: some View {
        let loading = container.authNotifier.state.isLoading

        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            VStack(spacing: 0) {
                header(topInset: topInset)

                // ---- White form sheet, pulled up to overlap the header ----
                formSheet(loading: loading)
                    .frame(maxHeight: .infinity)
                    .offset(y: -28)
            }
            .ignoresSafeArea(edges: .top)
        }
        // White so the bottom of the form sheet blends with the scaffold.
        .background(AppColors.surface.ignoresSafeArea())
        .task {
            guard !didInitState else { return }
            didInitState = true
            loadRememberedCredentials()
        }
    }

    // ---- Green hero header: logo + "Sign in" ----
    private func header(topInset: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(LocaleKeys.common_sign_in.tr())
                .textStyle(AppTypography.heading(34, color: Colors.white))
            VGap(8)
            Text(LocaleKeys.auth_welcome_back_sign_in_to_manage.tr())
                .textStyle(AppTypography.body(
                    14,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.4
                ))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24, topInset + 40, 24, 52)
        .background {
            // Slight dark scrim keeps the white logo / title readable on top
            // of the photo background (ColorFilter darken, black @ 30%).
            AppImage(AppAssets.loginBackground, fit: .cover)
                .overlay { Colors.black.withValues(alpha: 0.30) }
        }
        .clipped()
    }

    private func formSheet(loading: Bool) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                AppImage(AppAssets.brandLogo, height: 64)
                VGap(24)
                if passwordReset {
                    AuthNotice.success("Your password has been reset. Please sign in.")
                    VGap(20)
                }
                LabeledField(label: LocaleKeys.common_email.tr()) {
                    AppTextField(
                        text: $email,
                        hintText: LocaleKeys.auth_enter_email.tr(),
                        prefixIcon: Icons.email_outlined,
                        errorText: emailError,
                        keyboardType: .emailAddress,
                        autocapitalization: .never,
                        submitLabel: .next
                    )
                }
                VGap(18)
                LabeledField(label: LocaleKeys.auth_password.tr()) {
                    AppTextField(
                        text: $password,
                        hintText: LocaleKeys.auth_enter_password.tr(),
                        prefixIcon: Icons.lock_outline,
                        errorText: passwordError,
                        isSecure: obscurePassword,
                        autocapitalization: .never,
                        submitLabel: .done,
                        onSubmitted: { Task { await submit() } }
                    ) {
                        Button {
                            obscurePassword.toggle()
                        } label: {
                            Icon(
                                obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: AppColors.textSecondary
                            )
                            .frame(width: 48, height: 48)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                VGap(4)
                HStack(spacing: 0) {
                    CheckboxView(value: rememberMe, enabled: !loading) { value in
                        let remember = value
                        rememberMe = remember
                        if !remember {
                            RememberedCredentialsStore.clear()
                        }
                    }
                    Text("Remember me")
                        .textStyle(AppTypography.body(13, weight: .w600, color: AppColors.textSecondary))
                    Spacer(minLength: 0)
                    Button {
                        Task { await forgotPassword() }
                    } label: {
                        Text(LocaleKeys.auth_forgot_password.tr())
                            .textStyle(AppTypography.body(13, weight: .w600, color: AppColors.textSecondary))
                    }
                    .buttonStyle(TextButtonStyle())
                    .disabled(loading)
                }
                VGap(16)
                Button {
                    Task { await submit() }
                } label: {
                    if loading {
                        ProgressView()
                            .tint(Colors.white)
                            .frame(width: 22, height: 22)
                    } else {
                        Text(LocaleKeys.common_sign_in.tr())
                    }
                }
                .buttonStyle(ElevatedButtonStyle())
                .disabled(loading)
                VGap(16)
                Button {
                    Task { await continueWithGoogle() }
                } label: {
                    HStack(spacing: 0) {
                        AppImage(AppAssets.googleLogo, width: 22, height: 22)
                        HGap(8)
                        Text("Continue with Google")
                    }
                }
                .buttonStyle(OutlinedButtonStyle())
                .disabled(loading)
                VGap(16)
                Button {
                    router.push(.signUp)
                } label: {
                    Text("Don't have an account? ")
                        .styled(AppTypography.body(14, color: AppColors.textSecondary))
                        + Text("Register")
                        .styled(AppTypography.body(14, weight: .w700, color: AppColors.primary))
                }
                .buttonStyle(.plain)
            }
            .padding(24, 36, 24, 24)
            .contentShape(Rectangle())
            // `onTapOutside: _dismissKeyboard` on both fields.
            .onTapGesture { dismissKeyboard() }
        }
        .background(
            UnevenRoundedRectangle(cornerRadii: BorderRadius.vertical(top: 28), style: .circular)
                .fill(AppColors.surface)
        )
    }

    // MARK: - Logic

    private func loadRememberedCredentials() {
        // A device storage failure must not prevent access to the sign-in
        // form — Keychain reads return nil rather than throwing.
        guard let saved = RememberedCredentialsStore.read() else { return }
        email = saved.email
        password = saved.password
        rememberMe = true
    }

    /// `_formKey.currentState!.validate()`.
    private func validate() -> Bool {
        emailError = email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Enter your email"
            : nil
        passwordError = password.count < 4 ? "Enter your password" : nil
        return emailError == nil && passwordError == nil
    }

    private func submit() async {
        guard validate() else { return }
        let auth = container.authNotifier
        let email = self.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = self.password

        let outcome = await auth.login(username: email, password: password)
        if Task.isCancelled { return }
        guard let outcome else {
            showAuthError()
            return
        }
        // The password was accepted either way, so the "remember me" choice is
        // honoured now — a two-step account finishes signing in on the next
        // screen, not here. A Keychain failure leaves nothing remembered and the
        // sign-in continues.
        if rememberMe {
            RememberedCredentialsStore.save(email: email, password: password)
        } else {
            RememberedCredentialsStore.clear()
        }
        if Task.isCancelled { return }

        // Two-factor account: hand over to the verification screen, which pops
        // true once the emailed code has been accepted.
        if let challenge = outcome.twoFactor {
            let verified = await router.pushForResult(
                .twoStepVerification(userId: challenge.userId, email: challenge.email),
                as: Bool.self
            )
            if verified != true {
                // Backed out, or the code was never accepted: drop the challenge so a
                // fresh attempt starts from the password again.
                auth.cancelTwoFactorSignIn()
                return
            }
            if Task.isCancelled { return }
        }
        finishSignIn()
    }

    /// Leaves the sign-in flow once a session exists.
    private func finishSignIn() {
        // Launched from a flow that wants to resume where it left off (e.g. the
        // payment page): just pop back so the caller sees the signed-in state.
        if popOnSuccess {
            router.pop(true)
            return
        }
        // Close the login flow back to the app shell.
        router.popUntilRoot()
    }

    /// Runs the forgot / reset password screens. They hand back the address
    /// whose password was reset, or nil when the user backed out.
    private func forgotPassword() async {
        let resetEmail = await router.pushForResult(
            .forgotPassword(email: email.trimmingCharacters(in: .whitespacesAndNewlines)),
            as: String.self
        )
        guard !Task.isCancelled, let resetEmail else { return }
        passwordReset = true
        email = resetEmail
        // Whatever was typed or remembered here is the old password now.
        password = ""
    }

    private func continueWithGoogle() async {
        let ok = await container.authNotifier.signInWithGoogle()
        guard !Task.isCancelled, let ok else { return }
        if ok {
            router.replaceAll([.mainShell])
            return
        }
        showAuthError()
    }

    private func showAuthError() {
        guard let err = container.authNotifier.state.error?.trimmingCharacters(in: .whitespacesAndNewlines),
              !err.isEmpty else { return }
        SnackBarCenter.shared.show(err)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// A field with a bold caption label sitting above it.
private struct LabeledField<Child: View>: View {
    let label: String
    @ViewBuilder let child: () -> Child

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .textStyle(AppTypography.body(14, weight: .w600, color: AppColors.textPrimary))
                .padding(.leading, 4)
                .padding(.bottom, 8)
            child()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Material 3 `Checkbox`: an 18pt rounded square in a 48pt tap target, brand
/// green with a white check when on, an outlined box when off.
private struct CheckboxView: View {
    let value: Bool
    let enabled: Bool
    let onChanged: (Bool) -> Void

    /// M3 `onSurfaceVariant` for the brand seed (the unchecked outline).
    private static let outline = Color(0xFF43483E)

    var body: some View {
        Button {
            onChanged(!value)
        } label: {
            ZStack {
                if value {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(enabled ? AppColors.primary : AppTheme.disabledForeground)
                    CheckMark()
                        .stroke(Colors.white, style: StrokeStyle(lineWidth: 2, lineCap: .butt, lineJoin: .miter))
                } else {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(enabled ? CheckboxView.outline : AppTheme.disabledForeground, lineWidth: 2)
                }
            }
            .frame(width: 18, height: 18)
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// The check glyph Material's checkbox painter strokes.
private struct CheckMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.15, y: rect.height * 0.45))
        path.addLine(to: CGPoint(x: rect.width * 0.4, y: rect.height * 0.7))
        path.addLine(to: CGPoint(x: rect.width * 0.85, y: rect.height * 0.25))
        return path
    }
}
