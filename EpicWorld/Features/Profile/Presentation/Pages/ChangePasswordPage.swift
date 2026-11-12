// Port of lib/features/profile/presentation/pages/change_password_page.dart
import SwiftUI

/// CHANGE PASSWORD — current / new / confirm-new fields with validation.
struct ChangePasswordPage: View {
    init() {}

    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router

    @State private var current = ""
    @State private var next = ""
    @State private var confirm = ""

    @State private var obscureCurrent = true
    @State private var obscureNext = true
    @State private var obscureConfirm = true

    // Form validation results (`_formKey.currentState!.validate()`).
    @State private var currentError: String?
    @State private var nextError: String?
    @State private var confirmError: String?

    var body: some View {
        let loading = container.authNotifier.state.isLoading

        Scaffold(
            backgroundColor: AppColors.surface,
            appBar: {
                AppBar(
                    title: LocaleKeys.profile_change_password.tr(),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    centerTitle: true
                )
            }
        ) {
            ScrollView {
                VStack(spacing: 0) {
                    Text("For your security, choose a strong password you don't use elsewhere.")
                        .textStyle(AppTypography.body(13.5, color: AppColors.textSecondary, height: 1.4))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    VGap(24)

                    FloatingLabelBox(label: LocaleKeys.profile_current_password.tr()) {
                        PasswordField(
                            text: $current,
                            hint: "Enter current password",
                            obscure: obscureCurrent,
                            onToggle: { obscureCurrent.toggle() },
                            errorText: currentError
                        )
                    }
                    VGap(20)

                    FloatingLabelBox(label: LocaleKeys.profile_new_password.tr()) {
                        PasswordField(
                            text: $next,
                            hint: "Enter new password",
                            obscure: obscureNext,
                            onToggle: { obscureNext.toggle() },
                            errorText: nextError
                        )
                    }
                    VGap(20)

                    FloatingLabelBox(label: LocaleKeys.profile_confirm_new_password.tr()) {
                        PasswordField(
                            text: $confirm,
                            hint: "Re-enter new password",
                            obscure: obscureConfirm,
                            onToggle: { obscureConfirm.toggle() },
                            errorText: confirmError,
                            onSubmitted: { Task { await submit() } }
                        )
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
                            Text(LocaleKeys.profile_update_password.tr())
                        }
                    }
                    .buttonStyle(ElevatedButtonStyle())
                    .disabled(loading)
                }
                .padding(24, 28, 24, 32)
            }
        }
    }

    /// `_formKey.currentState!.validate()`.
    private func validate() -> Bool {
        currentError = current.isEmpty ? "Enter your current password" : nil
        nextError = next.count < 6 ? "At least 6 characters" : nil
        confirmError = confirm != next ? "Passwords do not match" : nil
        return currentError == nil && nextError == nil && confirmError == nil
    }

    private func submit() async {
        guard validate() else { return }
        let auth = container.authNotifier
        let ok = await auth.changePassword(current: current, next: next)
        if Task.isCancelled { return }
        if ok {
            SnackBarCenter.shared.show(
                LocaleKeys.profile_password_changed_successfully.tr(),
                floating: true
            )
            await router.maybePop()
        } else {
            guard let error = container.authNotifier.state.error?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !error.isEmpty else { return }
            SnackBarCenter.shared.show(error, floating: true)
        }
    }
}

private struct PasswordField: View {
    @Binding var text: String
    let hint: String
    let obscure: Bool
    let onToggle: () -> Void
    let errorText: String?
    var onSubmitted: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            // `_innerDecoration(hint)` — borderless, dense, the box draws the
            // border; the validator message sits under the text.
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    if obscure {
                        SecureField("", text: $text, prompt: prompt)
                    } else {
                        TextField("", text: $text, prompt: prompt)
                    }
                }
                .font(AppTypography.body(14, weight: .w600).font)
                .foregroundStyle(AppColors.textPrimary)
                .tint(AppColors.primary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(onSubmitted != nil ? .done : .next)
                .onSubmit { onSubmitted?() }
                if let errorText {
                    Text(errorText)
                        .textStyle(AppTypography.bodySmall.copyWith(color: AppColors.error))
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HGap(8)
            // Show / hide toggle, kept inside the field box like the design.
            Button(action: onToggle) {
                Icon(
                    obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20,
                    color: AppColors.textTertiary
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(InkButtonStyle(cornerRadius: 22))
        }
    }

    private var prompt: Text {
        Text(hint)
            .font(AppTypography.body(14).font)
            .foregroundColor(AppColors.textPlaceholder)
    }
}

/// A rounded, bordered input box with an uppercase caption floating on its top
/// border — the label's surface background notches the border, matching the
/// rest of the app's form fields.
private struct FloatingLabelBox<Child: View>: View {
    let label: String
    @ViewBuilder let child: () -> Child

    var body: some View {
        child()
            // EdgeInsets.symmetric(14, 15) plus the 1pt border.
            .padding(horizontal: 15, vertical: 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .boxDecoration(color: AppColors.surface, radius: 14, borderColor: AppColors.border)
            .padding(.top, 7)
            .overlay(alignment: .topLeading) {
                Text(label.uppercased())
                    .textStyle(AppTypography.body(11.5, weight: .w400, color: AppColors.textPrimary, letterSpacing: 0.5))
                    .padding(.horizontal, 4)
                    .background(AppColors.surface)
                    .padding(.leading, 12)
            }
    }
}
