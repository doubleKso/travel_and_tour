// Port of lib/features/auth/presentation/widgets/password_reset_layout.dart
import SwiftUI

/// Shared frame for the forgot / reset password screens: an app bar with the
/// back arrow, then the logo, the heading and its lead copy, then the form.
struct PasswordResetLayout<Subtitle: View, Children: View>: View {
    let title: String

    /// Lead copy under the heading; plain `Text` picks up the muted body style.
    let subtitle: () -> Subtitle

    /// Nil while a request is in flight, which disables the back arrow.
    let onBack: (() -> Void)?

    let children: () -> Children

    init(
        title: String,
        @ViewBuilder subtitle: @escaping () -> Subtitle,
        onBack: (() -> Void)?,
        @ViewBuilder children: @escaping () -> Children
    ) {
        self.title = title
        self.subtitle = subtitle
        self.onBack = onBack
        self.children = children
    }

    var body: some View {
        Scaffold(
            backgroundColor: AppColors.surface,
            appBar: {
                AppBar(
                    backgroundColor: AppColors.surface,
                    leading: {
                        // IconButton(tooltip: 'Back', padding: zero) in a 56pt
                        // leading slot. A null `onPressed` only stops taps — the
                        // icon keeps its explicit colour.
                        Button {
                            onBack?()
                        } label: {
                            Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textPrimary)
                                .frame(width: 48, height: 48)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .allowsHitTesting(onBack != nil)
                        .accessibilityLabel("Back")
                        .frame(width: 56)
                    },
                    actions: { EmptyView() },
                    title: { EmptyView() }
                )
            }
        ) {
            ScrollView {
                VStack(spacing: 0) {
                    AppImage(AppAssets.brandLogo, height: 42, fit: .contain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    VGap(26)
                    Text(title)
                        .textStyle(AppTypography.heading(30, color: AppColors.textPrimary, height: 1.15))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    VGap(8)
                    subtitle()
                        .textStyle(AppTypography.body(15.5, color: AppColors.textSecondary, height: 1.45))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    children()
                }
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity)
                .padding(24, 8, 24, 32)
            }
        }
    }
}

/// Small caption sitting above a form field.
struct AuthFieldLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .textStyle(AppTypography.body(13, weight: .w600, color: AppColors.textSecondary))
            .padding(.bottom, 8)
    }
}

/// A tinted message box: red when a request failed, green to confirm one
/// that went through.
struct AuthNotice: View {
    let message: String
    /// Dart's `success` field (named apart from the `success(_:)` factory).
    let isSuccess: Bool

    private init(_ message: String, isSuccess: Bool) {
        self.message = message
        self.isSuccess = isSuccess
    }

    /// Dart `AuthNotice.error(message)`.
    static func error(_ message: String) -> AuthNotice {
        AuthNotice(message, isSuccess: false)
    }

    /// Dart `AuthNotice.success(message)`.
    static func success(_ message: String) -> AuthNotice {
        AuthNotice(message, isSuccess: true)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if isSuccess {
                Icon(Icons.check_rounded, size: 18, color: AppColors.primary)
                HGap(10)
            }
            Text(message)
                .textStyle(AppTypography.body(
                    14,
                    weight: .w500,
                    color: isSuccess ? AppColors.primaryDark : Color(0xFFE32222)
                ))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        // EdgeInsets.symmetric(16, 14) plus the 1pt border, which a Flutter
        // Container adds to its padding.
        .padding(horizontal: 17, vertical: 15)
        .frame(maxWidth: .infinity)
        .boxDecoration(
            color: isSuccess ? Color(0xFFF0F7EE) : Color(0xFFFFF1F1),
            radius: 13,
            borderColor: isSuccess ? Color(0xFFCFE3C6) : Color(0xFFFFD7D7)
        )
    }
}

/// The six-digit code input shared by the email verification, two-step and
/// reset screens: the app's input decoration around a digits-only, 6-character
/// field drawn in body 16 w600 with 10pt letter spacing and a `0 0 0 0 0 0`
/// hint at 7pt spacing.
///
/// Feature-local helper: `AppTextField` has no letter spacing or centred-text
/// option, both of which these fields need.
struct AuthCodeField: View {
    @Binding var text: String
    var enabled = true
    var autofocus = false
    /// `TextAlign.center` (the verification screens) or start (reset code).
    var centered = false
    var errorText: String? = nil
    /// `autofillHints: [AutofillHints.oneTimeCode]` where the Dart field sets it.
    var textContentType: UITextContentType? = nil
    var onSubmitted: (() -> Void)? = nil
    var onChanged: ((String) -> Void)? = nil

    @FocusState private var focused: Bool

    init(
        text: Binding<String>,
        enabled: Bool = true,
        autofocus: Bool = false,
        centered: Bool = false,
        errorText: String? = nil,
        textContentType: UITextContentType? = nil,
        onSubmitted: (() -> Void)? = nil,
        onChanged: ((String) -> Void)? = nil
    ) {
        _text = text
        self.enabled = enabled
        self.autofocus = autofocus
        self.centered = centered
        self.errorText = errorText
        self.textContentType = textContentType
        self.onSubmitted = onSubmitted
        self.onChanged = onChanged
    }

    private var borderColor: Color {
        if errorText != nil { return AppColors.error }
        if focused { return AppColors.primary }
        return AppColors.border
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(
                "",
                text: $text,
                prompt: Text("0 0 0 0 0 0")
                    .font(AppTypography.body(16).font)
                    .foregroundColor(AppColors.textPlaceholder)
                    .tracking(7)
            )
            .font(AppTypography.body(16, weight: .w600).font)
            .tracking(10)
            .foregroundStyle(AppColors.textPrimary)
            .multilineTextAlignment(centered ? .center : .leading)
            .keyboardType(.numberPad)
            .textContentType(textContentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .submitLabel(.done)
            .tint(AppColors.primary)
            .disabled(!enabled)
            .focused($focused)
            .onSubmit { onSubmitted?() }
            .onChange(of: text) { _, newValue in
                // FilteringTextInputFormatter.digitsOnly +
                // LengthLimitingTextInputFormatter(6).
                let filtered = String(newValue.filter { ("0"..."9").contains($0) }.prefix(6))
                if filtered != newValue {
                    text = filtered
                    return
                }
                onChanged?(newValue)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusSm, style: .continuous)
                    .fill(enabled ? AppColors.surface : AppColors.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusSm, style: .continuous)
                    .stroke(borderColor, lineWidth: focused && errorText == nil ? 1.6 : 1)
            )
            .contentShape(Rectangle())
            .onTapGesture { if enabled { focused = true } }
            if let errorText {
                Text(errorText)
                    .textStyle(AppTypography.body(12, color: AppColors.error))
                    .padding(.top, 6)
                    .padding(.horizontal, 12)
            }
        }
        .opacity(enabled ? 1 : 0.6)
        .task {
            guard autofocus else { return }
            // `autofocus: true` — wait out the push transition, which would
            // otherwise swallow the focus request.
            try? await Task.sleep(for: .milliseconds(350))
            focused = true
        }
    }
}
