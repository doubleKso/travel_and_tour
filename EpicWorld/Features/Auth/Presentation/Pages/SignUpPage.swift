// Port of lib/features/auth/presentation/pages/sign_up_page.dart
import SwiftUI
import UIKit

/// SIGN UP — mirrors the login screen: photo hero header above a white sheet
/// that carries the logo and the registration form.
struct SignUpPage: View {
    init() {}

    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router

    @State private var fullName = ""
    /// The username field is commented out in the Dart form, so this stays
    /// empty — and is still what `register` receives, as in Dart.
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var obscurePassword = true
    @State private var obscureConfirm = true

    // Form validation results (`_formKey.currentState!.validate()`).
    @State private var fullNameError: String?
    @State private var emailError: String?
    @State private var passwordError: String?
    @State private var confirmError: String?

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
        .background(AppColors.surface.ignoresSafeArea())
    }

    // ---- Photo hero header: "Sign up" ----
    private func header(topInset: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                Task { await router.maybePop() }
            } label: {
                Icon(Icons.arrow_back, color: Colors.white)
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            VGap(8)
            VStack(alignment: .leading, spacing: 0) {
                Text(LocaleKeys.common_sign_up.tr())
                    .textStyle(AppTypography.heading(34, color: Colors.white))
                VGap(8)
                Text(LocaleKeys.auth_create_account_to_start_booking_trips.tr())
                    .textStyle(AppTypography.body(
                        14,
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.4
                    ))
            }
            .padding(.leading, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8, topInset + 8, 24, 52)
        .background {
            AppImage(AppAssets.loginBackground, fit: .cover)
                .overlay { Colors.black.withValues(alpha: 0.30) }
        }
        .clipped()
    }

    private func formSheet(loading: Bool) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                AppImage(AppAssets.brandLogo, height: 64)
                VGap(28)
                LabeledField(label: LocaleKeys.common_full_name.tr()) {
                    AppTextField(
                        text: $fullName,
                        hintText: LocaleKeys.auth_enter_full_name.tr(),
                        prefixIcon: Icons.badge_outlined,
                        errorText: fullNameError,
                        autocapitalization: .never,
                        submitLabel: .next
                    )
                }
                // The username field is commented out in the Dart form
                // (LocaleKeys.auth_username / auth_choose_username, person_outline).
                VGap(18)
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
                LabeledField(label: LocaleKeys.auth_password.tr(), labelHint: "(At least 8 characters)") {
                    AppTextField(
                        text: $password,
                        hintText: LocaleKeys.auth_create_password.tr(),
                        prefixIcon: Icons.lock_outline,
                        errorText: passwordError,
                        isSecure: obscurePassword,
                        autocapitalization: .never,
                        submitLabel: .next
                    ) {
                        visibilityToggle(obscured: obscurePassword) { obscurePassword.toggle() }
                    }
                }
                VGap(18)
                LabeledField(label: LocaleKeys.auth_confirm_password.tr()) {
                    AppTextField(
                        text: $confirm,
                        hintText: LocaleKeys.auth_re_enter_password.tr(),
                        prefixIcon: Icons.lock_outline,
                        errorText: confirmError,
                        isSecure: obscureConfirm,
                        autocapitalization: .never,
                        submitLabel: .done,
                        onSubmitted: { Task { await submit() } }
                    ) {
                        visibilityToggle(obscured: obscureConfirm) { obscureConfirm.toggle() }
                    }
                }
                VGap(28)
                Button {
                    Task { await submit() }
                } label: {
                    if loading {
                        ProgressView()
                            .tint(Colors.white)
                            .frame(width: 22, height: 22)
                    } else {
                        Text(LocaleKeys.common_sign_up.tr())
                    }
                }
                .buttonStyle(ElevatedButtonStyle())
                .disabled(loading)
                // The "Continue with Google" button is commented out in Dart.
                VGap(24)
                Button {
                    Task { await router.maybePop() }
                } label: {
                    Text("Already have an account? ")
                        .styled(AppTypography.body(14, color: AppColors.textSecondary))
                        + Text("Sign in")
                        .styled(AppTypography.body(14, weight: .w700, color: AppColors.primary))
                }
                .buttonStyle(.plain)
            }
            .padding(24, 36, 24, 24)
            .contentShape(Rectangle())
            // `onTapOutside: _dismissKeyboard` on every field.
            .onTapGesture { dismissKeyboard() }
        }
        .background(
            UnevenRoundedRectangle(cornerRadii: BorderRadius.vertical(top: 28), style: .circular)
                .fill(AppColors.surface)
        )
    }

    /// The fields' `suffixIcon: IconButton(visibility…)`.
    private func visibilityToggle(obscured: Bool, onPressed: @escaping () -> Void) -> some View {
        Button(action: onPressed) {
            Icon(
                obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.textSecondary
            )
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Logic

    /// `_formKey.currentState!.validate()`.
    private func validate() -> Bool {
        fullNameError = fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Enter your full name"
            : nil
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            emailError = "Enter your email"
        } else if !email.contains("@") || !email.contains(".") {
            emailError = "Enter a valid email"
        } else {
            emailError = nil
        }
        passwordError = password.count < 8 ? "Use at least 8 characters" : nil
        confirmError = confirm != password ? "Passwords do not match" : nil
        return fullNameError == nil && emailError == nil && passwordError == nil && confirmError == nil
    }

    private func submit() async {
        guard validate() else { return }
        let user = await container.authNotifier.register(
            fullName: fullName,
            username: username,
            email: email,
            password: password
        )
        if Task.isCancelled { return }
        if let user {
            router.push(.emailVerification(userId: user.id, email: user.email))
        } else {
            showAuthError()
        }
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
    let labelHint: String?
    let child: () -> Child

    init(label: String, labelHint: String? = nil, @ViewBuilder child: @escaping () -> Child) {
        self.label = label
        self.labelHint = labelHint
        self.child = child
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Text(label)
                    .textStyle(AppTypography.body(14, weight: .w600, color: AppColors.textPrimary))
                if let labelHint {
                    HGap(5)
                    Text(labelHint)
                        .textStyle(AppTypography.body(12, color: AppColors.textPrimary))
                }
            }
            .padding(.leading, 4)
            .padding(.bottom, 8)
            child()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
