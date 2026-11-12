// Port of lib/features/auth/presentation/pages/reset_password_page.dart
import SwiftUI
import UIKit

/// RESET PASSWORD — the emailed reset code plus a new password, confirmed
/// twice, sent to `authResetPasswordWithOtp`.
///
/// Pops `true` once the password has been reset. Going back returns to the
/// forgot password screen, so a mistyped address can be corrected.
struct ResetPasswordPage: View {
    /// Address the reset code was sent to.
    let email: String

    init(email: String) {
        self.email = email
    }

    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router

    @State private var code = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var showPassword = false
    @State private var error: String?

    // Form validation results (`_formKey.currentState!.validate()`).
    @State private var codeError: String?
    @State private var passwordError: String?
    @State private var confirmError: String?

    var body: some View {
        let loading = container.authNotifier.state.isLoading

        PasswordResetLayout(
            title: "Reset your password",
            subtitle: {
                Text("We've sent a reset code to\n")
                    + Text(email)
                    .styled(AppTypography.body(15.5, weight: .w700, color: AppColors.textPrimary))
            },
            onBack: loading ? nil : goBack
        ) {
            if let error {
                VGap(18)
                AuthNotice.error(error)
            }
            VGap(26)
            VStack(spacing: 0) {
                AuthFieldLabel("Reset code")
                    .frame(maxWidth: .infinity, alignment: .leading)
                AuthCodeField(
                    text: $code,
                    enabled: !loading,
                    errorText: codeError,
                    textContentType: .oneTimeCode,
                    onChanged: clearError
                )
                VGap(18)
                AuthFieldLabel("New password")
                    .frame(maxWidth: .infinity, alignment: .leading)
                AppTextField(
                    text: $password,
                    hintText: "At least 8 characters",
                    prefixIcon: Icons.lock_outline,
                    errorText: passwordError,
                    isSecure: !showPassword,
                    textContentType: .newPassword,
                    autocapitalization: .never,
                    submitLabel: .next,
                    enabled: !loading,
                    onChanged: clearError
                )
                VGap(18)
                AuthFieldLabel("Confirm new password")
                    .frame(maxWidth: .infinity, alignment: .leading)
                AppTextField(
                    text: $confirm,
                    hintText: "Re-enter your new password",
                    prefixIcon: Icons.lock_outline,
                    errorText: confirmError,
                    isSecure: !showPassword,
                    textContentType: .newPassword,
                    autocapitalization: .never,
                    submitLabel: .done,
                    enabled: !loading,
                    onSubmitted: { Task { await reset() } },
                    onChanged: clearError
                )
                VGap(4)
                HStack(spacing: 0) {
                    CheckboxView(value: showPassword, enabled: !loading) { value in
                        showPassword = value
                    }
                    Text("Show password")
                        .textStyle(AppTypography.body(13, weight: .w600, color: AppColors.textSecondary))
                    Spacer(minLength: 0)
                }
                VGap(12)
                Button {
                    Task { await reset() }
                } label: {
                    if loading {
                        ProgressView()
                            .tint(Colors.white)
                            .frame(width: 22, height: 22)
                    } else {
                        Text("Reset password")
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
            .contentShape(Rectangle())
            // `onTapOutside: _dismissKeyboard`.
            .onTapGesture { dismissKeyboard() }
        }
    }

    // MARK: - Validators

    /// The reset-code field's `validator`.
    static func validateCode(_ value: String) -> String? {
        value.trimmingCharacters(in: .whitespacesAndNewlines).count != 6
            ? "Enter the 6-digit code we emailed you"
            : nil
    }

    /// The new-password field's `validator`.
    static func validatePassword(_ value: String) -> String? {
        value.count < 8 ? "Use at least 8 characters" : nil
    }

    /// The confirm field's `validator`.
    static func validateConfirm(_ value: String, password: String) -> String? {
        value != password ? "Passwords do not match" : nil
    }

    // MARK: - Logic

    private func reset() async {
        // `_formKey.currentState!.validate()`.
        codeError = ResetPasswordPage.validateCode(code)
        passwordError = ResetPasswordPage.validatePassword(password)
        confirmError = ResetPasswordPage.validateConfirm(confirm, password: password)
        guard codeError == nil, passwordError == nil, confirmError == nil else { return }
        error = nil
        let ok = await container.authNotifier.resetPassword(
            email: email,
            code: code.trimmingCharacters(in: .whitespacesAndNewlines),
            newPassword: password
        )
        if Task.isCancelled { return }
        if ok {
            router.pop(true)
            return
        }
        error = authError() ?? "Your password could not be reset."
    }

    private func resend() async {
        let sent = await container.authNotifier.requestPasswordReset(email: email)
        if Task.isCancelled { return }
        if sent {
            error = nil
            SnackBarCenter.shared.show("A new code has been sent.")
            return
        }
        error = authError() ?? "Unable to send a new code."
    }

    private func authError() -> String? {
        let error = container.authNotifier.state.error?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let error, !error.isEmpty else { return nil }
        return error
    }

    private func clearError(_ value: String) {
        if error != nil { error = nil }
    }

    /// `Navigator.of(context).maybePop()`.
    private func goBack() {
        Task { await router.maybePop() }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
