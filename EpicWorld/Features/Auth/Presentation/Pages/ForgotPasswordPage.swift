// Port of lib/features/auth/presentation/pages/forgot_password_page.dart
import SwiftUI
import UIKit

/// FORGOT PASSWORD — asks for the account email and has
/// `authRequestPasswordOtp` send a reset code to it, then hands over to the
/// reset screen.
///
/// Pops the email address once its password has been reset, so the sign-in
/// page can confirm it and prefill the form; pops nil otherwise.
struct ForgotPasswordPage: View {
    /// Address carried over from the sign-in form, so it need not be retyped.
    let email: String

    init(email: String = "") {
        self.email = email
        _emailText = State(initialValue: email)
    }

    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router

    /// `late final _email = TextEditingController(text: widget.email)`.
    @State private var emailText: String
    @State private var error: String?
    @State private var emailError: String?

    var body: some View {
        let loading = container.authNotifier.state.isLoading

        PasswordResetLayout(
            title: "Forgot your password?",
            subtitle: { Text("Enter your email and we'll send you a reset code.") },
            onBack: loading ? nil : goBack
        ) {
            if let error {
                VGap(18)
                AuthNotice.error(error)
            }
            VGap(26)
            VStack(spacing: 0) {
                AuthFieldLabel("Email")
                    .frame(maxWidth: .infinity, alignment: .leading)
                AppTextField(
                    text: $emailText,
                    hintText: "you@example.com",
                    prefixIcon: Icons.email_outlined,
                    errorText: emailError,
                    keyboardType: .emailAddress,
                    textContentType: .emailAddress,
                    autocapitalization: .never,
                    submitLabel: .done,
                    enabled: !loading,
                    onSubmitted: { Task { await sendCode() } },
                    onChanged: { _ in
                        if error != nil { error = nil }
                    }
                )
                VGap(20)
                Button {
                    Task { await sendCode() }
                } label: {
                    if loading {
                        ProgressView()
                            .tint(Colors.white)
                            .frame(width: 22, height: 22)
                    } else {
                        Text("Send reset code")
                    }
                }
                .buttonStyle(ElevatedButtonStyle())
                .disabled(loading)
            }
            .contentShape(Rectangle())
            // `onTapOutside: _dismissKeyboard`.
            .onTapGesture { dismissKeyboard() }
        }
    }

    /// The email field's `validator`.
    static func validateEmail(_ value: String) -> String? {
        let email = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if email.isEmpty { return "Enter your email" }
        if !email.contains("@") || !email.contains(".") {
            return "Enter a valid email"
        }
        return nil
    }

    private func sendCode() async {
        // `_formKey.currentState!.validate()`.
        emailError = ForgotPasswordPage.validateEmail(emailText)
        guard emailError == nil else { return }
        error = nil
        let email = emailText.trimmingCharacters(in: .whitespacesAndNewlines)
        let sent = await container.authNotifier.requestPasswordReset(email: email)
        if Task.isCancelled { return }
        if !sent {
            error = authError() ?? "Unable to send a reset code."
            return
        }
        // Anything but true means the user came back here, e.g. to correct the
        // address, so this screen stays.
        let reset = await router.pushForResult(.resetPassword(email: email), as: Bool.self)
        if Task.isCancelled || reset != true { return }
        router.pop(email)
    }

    /// `Navigator.of(context).maybePop()`.
    private func goBack() {
        Task { await router.maybePop() }
    }

    private func authError() -> String? {
        let error = container.authNotifier.state.error?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let error, !error.isEmpty else { return nil }
        return error
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
