import SwiftUI

/// Global theme values and the Material component styles the Flutter theme
/// configures — the port of `app_ui_kit`'s `AppTheme`.
enum AppTheme {
    /// Standard corner radius used across cards, buttons and sheets.
    static let radius: CGFloat = 16
    static let radiusSm: CGFloat = 10
    static let radiusLg: CGFloat = 24

    /// Material's default toolbar height (`kToolbarHeight`).
    static let toolbarHeight: CGFloat = 56

    /// Flutter's disabled foreground/background (onSurface at 38% / 12%).
    static let disabledForeground = AppColors.textPrimary.withValues(alpha: 0.38)
    static let disabledBackground = AppColors.textPrimary.withValues(alpha: 0.12)
}

/// `ElevatedButton` as themed by `AppTheme.light`: filled brand green, white
/// label, 54pt tall, full width, 16pt corners, body 16 w600. Every parameter
/// mirrors an `ElevatedButton.styleFrom` override.
///
/// ```swift
/// Button(LocaleKeys.common_continue.tr()) { … }.buttonStyle(ElevatedButtonStyle())
/// Button { … } label: { … }.buttonStyle(ElevatedButtonStyle(backgroundColor: AppColors.accent, minimumHeight: 48))
/// ```
struct ElevatedButtonStyle: ButtonStyle {
    var backgroundColor: Color = AppColors.primary
    var foregroundColor: Color = Colors.white
    var disabledBackgroundColor: Color = AppTheme.disabledBackground
    var disabledForegroundColor: Color = AppTheme.disabledForeground
    var minimumHeight: CGFloat = 54
    var fullWidth: Bool = true
    var cornerRadius: CGFloat = AppTheme.radius
    var padding = EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)
    var textStyle: TextStyle = AppTypography.body(16, weight: .w600)
    var borderColor: Color? = nil
    var elevation: CGFloat = 0

    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let foreground = isEnabled ? foregroundColor : disabledForegroundColor
        configuration.label
            .font(textStyle.font)
            .tracking(textStyle.letterSpacing ?? 0)
            .foregroundStyle(foreground)
            .padding(padding)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: minimumHeight)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isEnabled ? backgroundColor : disabledBackgroundColor)
            )
            .overlay {
                if let borderColor {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(borderColor, lineWidth: 1)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(foreground.opacity(configuration.isPressed ? 0.10 : 0))
            )
            .shadow(color: Colors.black.withValues(alpha: elevation > 0 ? 0.2 : 0), radius: elevation, y: elevation / 2)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// `OutlinedButton` as themed: brand-green label and 1pt border, 54pt tall.
struct OutlinedButtonStyle: ButtonStyle {
    var foregroundColor: Color = AppColors.primary
    var borderColor: Color = AppColors.primary
    var backgroundColor: Color = Colors.transparent
    var borderWidth: CGFloat = 1
    var minimumHeight: CGFloat = 54
    var fullWidth: Bool = true
    var cornerRadius: CGFloat = AppTheme.radius
    var padding = EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)
    var textStyle: TextStyle = AppTypography.body(16, weight: .w600)

    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let foreground = isEnabled ? foregroundColor : AppTheme.disabledForeground
        configuration.label
            .font(textStyle.font)
            .tracking(textStyle.letterSpacing ?? 0)
            .foregroundStyle(foreground)
            .padding(padding)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: minimumHeight)
            .background(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(backgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(isEnabled ? borderColor : AppTheme.disabledBackground, lineWidth: borderWidth)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(foregroundColor.opacity(configuration.isPressed ? 0.08 : 0))
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// `TextButton`: a label with a press highlight and no fill.
struct TextButtonStyle: ButtonStyle {
    var foregroundColor: Color = AppColors.primary
    var textStyle: TextStyle = AppTypography.body(14, weight: .w500)
    var padding = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
    var minimumHeight: CGFloat = 40

    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(textStyle.font)
            .foregroundStyle(isEnabled ? foregroundColor : AppTheme.disabledForeground)
            .padding(padding)
            .frame(minHeight: minimumHeight)
            .background(
                Capsule().fill(foregroundColor.opacity(configuration.isPressed ? 0.10 : 0))
            )
            .contentShape(Rectangle())
    }
}

/// `InkWell` / `GestureDetector` tap target: no styling, a faint press
/// overlay like Material's splash (`splashColor: primary @ 8%`).
struct InkButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 0
    var highlight: Color = AppColors.primary.withValues(alpha: 0.08)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(configuration.isPressed ? highlight : Colors.transparent)
                    .allowsHitTesting(false)
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension ButtonStyle where Self == InkButtonStyle {
    /// `InkWell(onTap:)` look.
    static var ink: InkButtonStyle { InkButtonStyle() }
    static func ink(radius: CGFloat) -> InkButtonStyle { InkButtonStyle(cornerRadius: radius) }
}
