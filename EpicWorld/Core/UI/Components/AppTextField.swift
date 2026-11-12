import SwiftUI

/// A Material `TextFormField` with the app's `InputDecorationTheme`: white
/// fill, 16pt content padding, 10pt corners, `border` outline that turns brand
/// green (1.6pt) when focused and red with an error line underneath.
///
/// ```swift
/// // TextFormField(controller: _email, decoration: InputDecoration(
/// //   hintText: LocaleKeys.auth_enter_email.tr(), prefixIcon: Icon(Icons.email_outlined)),
/// //   keyboardType: TextInputType.emailAddress, validator: …)
/// AppTextField(text: $email, hintText: LocaleKeys.auth_enter_email.tr(),
///              prefixIcon: Icons.email_outlined, errorText: emailError,
///              keyboardType: .emailAddress, textContentType: .emailAddress)
/// ```
/// Validation stays in the page, as in Dart: compute `errorText` from the
/// same rules the `validator` used and pass it in.
struct AppTextField<Suffix: View>: View {
    @Binding var text: String
    var hintText: String? = nil
    var labelText: String? = nil
    var prefixIcon: IconData? = nil
    var errorText: String? = nil
    var helperText: String? = nil
    var isSecure = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .sentences
    var autocorrection = false
    var submitLabel: SubmitLabel = .done
    var minLines = 1
    var maxLines = 1
    var maxLength: Int? = nil
    var enabled = true
    /// Read-only fields act as buttons (date / picker fields in Dart).
    var readOnly = false
    var fillColor: Color = AppColors.surface
    var textStyle: TextStyle = AppTypography.body(15)
    var onTap: (() -> Void)? = nil
    var onSubmitted: (() -> Void)? = nil
    var onChanged: ((String) -> Void)? = nil
    @ViewBuilder var suffix: () -> Suffix

    @FocusState private var focused: Bool

    init(
        text: Binding<String>,
        hintText: String? = nil,
        labelText: String? = nil,
        prefixIcon: IconData? = nil,
        errorText: String? = nil,
        helperText: String? = nil,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        autocapitalization: TextInputAutocapitalization = .sentences,
        autocorrection: Bool = false,
        submitLabel: SubmitLabel = .done,
        minLines: Int = 1,
        maxLines: Int = 1,
        maxLength: Int? = nil,
        enabled: Bool = true,
        readOnly: Bool = false,
        fillColor: Color = AppColors.surface,
        textStyle: TextStyle = AppTypography.body(15),
        onTap: (() -> Void)? = nil,
        onSubmitted: (() -> Void)? = nil,
        onChanged: ((String) -> Void)? = nil,
        @ViewBuilder suffix: @escaping () -> Suffix
    ) {
        _text = text
        self.hintText = hintText
        self.labelText = labelText
        self.prefixIcon = prefixIcon
        self.errorText = errorText
        self.helperText = helperText
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.autocapitalization = autocapitalization
        self.autocorrection = autocorrection
        self.submitLabel = submitLabel
        self.minLines = minLines
        self.maxLines = maxLines
        self.maxLength = maxLength
        self.enabled = enabled
        self.readOnly = readOnly
        self.fillColor = fillColor
        self.textStyle = textStyle
        self.onTap = onTap
        self.onSubmitted = onSubmitted
        self.onChanged = onChanged
        self.suffix = suffix
    }

    private var borderColor: Color {
        if errorText != nil { return AppColors.error }
        if focused { return AppColors.primary }
        return AppColors.border
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let labelText {
                Text(labelText)
                    .textStyle(AppTypography.body(14, color: errorText != nil ? AppColors.error : (focused ? AppColors.primary : AppColors.textSecondary)))
                    .padding(.bottom, 6)
            }
            HStack(spacing: 0) {
                if let prefixIcon {
                    Icon(prefixIcon, size: 22, color: focused ? AppColors.primary : AppColors.textSecondary)
                        .frame(width: 48)
                }
                field
                    .padding(.leading, prefixIcon == nil ? 16 : 0)
                    .padding(.trailing, Suffix.self == EmptyView.self ? 16 : 4)
                    .padding(.vertical, 16)
                suffix()
                    .padding(.trailing, Suffix.self == EmptyView.self ? 0 : 8)
            }
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusSm, style: .continuous)
                    .fill(enabled ? fillColor : AppColors.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusSm, style: .continuous)
                    .stroke(borderColor, lineWidth: focused && errorText == nil ? 1.6 : 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if readOnly { onTap?() } else { focused = true; onTap?() }
            }
            if let message = errorText ?? helperText {
                Text(message)
                    .textStyle(AppTypography.body(12, color: errorText != nil ? AppColors.error : AppColors.textSecondary))
                    .padding(.top, 6)
                    .padding(.horizontal, 12)
            }
        }
        .opacity(enabled ? 1 : 0.6)
    }

    @ViewBuilder
    private var field: some View {
        let prompt = Text(hintText ?? "").font(textStyle.font).foregroundColor(AppColors.textPlaceholder)
        Group {
            if readOnly {
                Text(text.isEmpty ? (hintText ?? "") : text)
                    .textStyle(textStyle.copyWith(color: text.isEmpty ? AppColors.textPlaceholder : textStyle.color))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if isSecure {
                SecureField("", text: $text, prompt: prompt)
            } else if maxLines > 1 {
                TextField("", text: $text, prompt: prompt, axis: .vertical)
                    .lineLimit(minLines...maxLines)
            } else {
                TextField("", text: $text, prompt: prompt)
            }
        }
        .font(textStyle.font)
        .foregroundStyle(textStyle.color)
        .tint(AppColors.primary)
        .keyboardType(keyboardType)
        .textContentType(textContentType)
        .textInputAutocapitalization(autocapitalization)
        .autocorrectionDisabled(!autocorrection)
        .submitLabel(submitLabel)
        .disabled(!enabled || readOnly)
        .focused($focused)
        .onSubmit { onSubmitted?() }
        .onChange(of: text) { _, newValue in
            if let maxLength, newValue.count > maxLength {
                text = String(newValue.prefix(maxLength))
                return
            }
            onChanged?(newValue)
        }
    }
}

extension AppTextField where Suffix == EmptyView {
    init(
        text: Binding<String>,
        hintText: String? = nil,
        labelText: String? = nil,
        prefixIcon: IconData? = nil,
        errorText: String? = nil,
        helperText: String? = nil,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        autocapitalization: TextInputAutocapitalization = .sentences,
        submitLabel: SubmitLabel = .done,
        minLines: Int = 1,
        maxLines: Int = 1,
        maxLength: Int? = nil,
        enabled: Bool = true,
        readOnly: Bool = false,
        onTap: (() -> Void)? = nil,
        onSubmitted: (() -> Void)? = nil,
        onChanged: ((String) -> Void)? = nil
    ) {
        self.init(
            text: text, hintText: hintText, labelText: labelText, prefixIcon: prefixIcon,
            errorText: errorText, helperText: helperText, isSecure: isSecure,
            keyboardType: keyboardType, textContentType: textContentType,
            autocapitalization: autocapitalization, submitLabel: submitLabel,
            minLines: minLines, maxLines: maxLines, maxLength: maxLength,
            enabled: enabled, readOnly: readOnly, onTap: onTap,
            onSubmitted: onSubmitted, onChanged: onChanged, suffix: { EmptyView() }
        )
    }
}
