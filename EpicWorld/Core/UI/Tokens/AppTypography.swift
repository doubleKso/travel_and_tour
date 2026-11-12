import SwiftUI

/// Flutter's `FontWeight`, so ported styles read the same
/// (`FontWeight.w600`, `.bold`).
struct FontWeight: Hashable {
    let value: Font.Weight
    /// 100…900, for interpolation and comparisons.
    let index: Int

    static let w100 = FontWeight(value: .ultraLight, index: 100)
    static let w200 = FontWeight(value: .thin, index: 200)
    static let w300 = FontWeight(value: .light, index: 300)
    static let w400 = FontWeight(value: .regular, index: 400)
    static let w500 = FontWeight(value: .medium, index: 500)
    static let w600 = FontWeight(value: .semibold, index: 600)
    static let w700 = FontWeight(value: .bold, index: 700)
    static let w800 = FontWeight(value: .heavy, index: 800)
    static let w900 = FontWeight(value: .black, index: 900)
    static let normal = w400
    static let bold = w700
}

/// Flutter's `TextDecoration`.
enum TextDecoration: Hashable {
    case none, underline, lineThrough
}

/// Flutter's `TextStyle` — the subset this app uses. Apply it with
/// `.textStyle(style)`:
///
/// ```swift
/// Text(title).textStyle(AppTypography.heading(20))
/// Text(note).textStyle(AppTypography.body(13, color: AppColors.textSecondary, height: 1.4))
/// ```
struct TextStyle: Hashable {
    var family: String
    var size: CGFloat
    var weight: FontWeight
    var color: Color
    /// Line height as a multiple of `size` (Flutter's `height`).
    var height: CGFloat?
    var letterSpacing: CGFloat?
    var italic: Bool
    var decoration: TextDecoration
    var decorationColor: Color?

    init(
        family: String = AppTypography.bodyFamily,
        size: CGFloat = 14,
        weight: FontWeight = .w400,
        color: Color = AppColors.textPrimary,
        height: CGFloat? = nil,
        letterSpacing: CGFloat? = nil,
        italic: Bool = false,
        decoration: TextDecoration = .none,
        decorationColor: Color? = nil
    ) {
        self.family = family
        self.size = size
        self.weight = weight
        self.color = color
        self.height = height
        self.letterSpacing = letterSpacing
        self.italic = italic
        self.decoration = decoration
        self.decorationColor = decorationColor
    }

    var font: Font {
        let base = Font.custom(family, size: size).weight(weight.value)
        return italic ? base.italic() : base
    }

    var uiFont: UIFont {
        let descriptor = UIFontDescriptor(fontAttributes: [.family: family])
            .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight.uiWeight.rawValue]])
        return UIFont(descriptor: descriptor, size: size)
    }

    /// Flutter's `copyWith`.
    func copyWith(
        family: String? = nil,
        size: CGFloat? = nil,
        weight: FontWeight? = nil,
        color: Color? = nil,
        height: CGFloat? = nil,
        letterSpacing: CGFloat? = nil,
        italic: Bool? = nil,
        decoration: TextDecoration? = nil,
        decorationColor: Color? = nil
    ) -> TextStyle {
        TextStyle(
            family: family ?? self.family,
            size: size ?? self.size,
            weight: weight ?? self.weight,
            color: color ?? self.color,
            height: height ?? self.height,
            letterSpacing: letterSpacing ?? self.letterSpacing,
            italic: italic ?? self.italic,
            decoration: decoration ?? self.decoration,
            decorationColor: decorationColor ?? self.decorationColor
        )
    }

    /// The font's own line height relative to its size; Flutter's `height`
    /// replaces it, so only the difference becomes extra spacing.
    var naturalLineHeight: CGFloat {
        family == AppTypography.headingFamily ? 1.21 : 1.17
    }
}

extension FontWeight {
    var uiWeight: UIFont.Weight {
        switch index {
        case ..<150: return .ultraLight
        case ..<250: return .thin
        case ..<350: return .light
        case ..<450: return .regular
        case ..<550: return .medium
        case ..<650: return .semibold
        case ..<750: return .bold
        case ..<850: return .heavy
        default: return .black
        }
    }
}

/// Typography scale — the port of `app_ui_kit`'s `AppTypography`.
///
/// **Inter** for labels / titles / headings, **Roboto** for body text, as in
/// the Flutter app. Roboto is bundled (from the Flutter SDK); Inter is used
/// when its font files are added to Resources/Fonts (see README) and falls
/// back to the system font — which Inter closely resembles — until then.
enum AppTypography {
    static let headingFamily = "Inter"
    static let bodyFamily = "Roboto"

    /// Title / headline / label font (Inter).
    static func heading(
        _ size: CGFloat,
        weight: FontWeight = .w700,
        color: Color = AppColors.textPrimary,
        height: CGFloat? = nil,
        letterSpacing: CGFloat? = nil
    ) -> TextStyle {
        TextStyle(family: headingFamily, size: size, weight: weight, color: color, height: height, letterSpacing: letterSpacing)
    }

    /// Body / UI text in Roboto.
    static func body(
        _ size: CGFloat,
        weight: FontWeight = .w400,
        color: Color = AppColors.textPrimary,
        height: CGFloat? = nil,
        letterSpacing: CGFloat? = nil
    ) -> TextStyle {
        TextStyle(family: bodyFamily, size: size, weight: weight, color: color, height: height, letterSpacing: letterSpacing)
    }

    // Material 3 text theme slots (Flutter `Theme.of(context).textTheme.*`)
    // with the app's font mix: Inter for display/headline/titleLarge, Roboto
    // for the rest.
    static var displayLarge: TextStyle { heading(57, weight: .w700) }
    static var displayMedium: TextStyle { heading(45, weight: .w700) }
    static var displaySmall: TextStyle { heading(36, weight: .w700) }
    static var headlineLarge: TextStyle { heading(32, weight: .w700) }
    static var headlineMedium: TextStyle { heading(28, weight: .w700) }
    static var headlineSmall: TextStyle { heading(24, weight: .w700) }
    static var titleLarge: TextStyle { heading(22, weight: .w700) }
    static var titleMedium: TextStyle { body(16, weight: .w500, letterSpacing: 0.15) }
    static var titleSmall: TextStyle { body(14, weight: .w500, letterSpacing: 0.1) }
    static var bodyLarge: TextStyle { body(16, letterSpacing: 0.5) }
    static var bodyMedium: TextStyle { body(14, letterSpacing: 0.25) }
    static var bodySmall: TextStyle { body(12, letterSpacing: 0.4) }
    static var labelLarge: TextStyle { body(14, weight: .w500, letterSpacing: 0.1) }
    static var labelMedium: TextStyle { body(12, weight: .w500, letterSpacing: 0.5) }
    static var labelSmall: TextStyle { body(11, weight: .w500, letterSpacing: 0.5) }
}

private struct TextStyleModifier: ViewModifier {
    let style: TextStyle

    func body(content: Content) -> some View {
        let extra = max(0, ((style.height ?? style.naturalLineHeight) - style.naturalLineHeight) * style.size)
        content
            .font(style.font)
            .foregroundStyle(style.color)
            .tracking(style.letterSpacing ?? 0)
            .lineSpacing(extra)
            .padding(.vertical, extra / 2)
            .underline(style.decoration == .underline, color: style.decorationColor)
            .strikethrough(style.decoration == .lineThrough, color: style.decorationColor)
    }
}

extension View {
    /// Applies a Flutter-style `TextStyle` (font, colour, letter spacing,
    /// line height, decoration).
    func textStyle(_ style: TextStyle) -> some View {
        modifier(TextStyleModifier(style: style))
    }
}

extension Text {
    /// A styled `Text` that can still be concatenated with `+` (Flutter
    /// `TextSpan` children / `Text.rich`).
    func styled(_ style: TextStyle) -> Text {
        var text = self
            .font(style.font)
            .foregroundColor(style.color)
            .tracking(style.letterSpacing ?? 0)
        if style.decoration == .underline { text = text.underline(true, color: style.decorationColor) }
        if style.decoration == .lineThrough { text = text.strikethrough(true, color: style.decorationColor) }
        return text
    }
}
