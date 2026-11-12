import SwiftUI
import UIKit

extension Color {
    /// Flutter's `Color(0xAARRGGBB)`.
    init(_ argb: UInt32) {
        self.init(
            .sRGB,
            red: Double((argb >> 16) & 0xFF) / 255,
            green: Double((argb >> 8) & 0xFF) / 255,
            blue: Double(argb & 0xFF) / 255,
            opacity: Double((argb >> 24) & 0xFF) / 255
        )
    }

    /// Flutter's `color.withValues(alpha: a)` — *replaces* the alpha (SwiftUI's
    /// `.opacity` multiplies it instead).
    func withValues(alpha: Double) -> Color {
        Color(uiColor: UIColor(self).withAlphaComponent(alpha))
    }

    /// Flutter's deprecated `color.withOpacity(a)`; same as `withValues(alpha:)`.
    func withOpacity(_ alpha: Double) -> Color { withValues(alpha: alpha) }

    /// Flutter's `Color.lerp(a, b, t)`.
    static func lerp(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let ca = UIColor(a).rgba, cb = UIColor(b).rgba
        return Color(
            .sRGB,
            red: ca.r + (cb.r - ca.r) * t,
            green: ca.g + (cb.g - ca.g) * t,
            blue: ca.b + (cb.b - ca.b) * t,
            opacity: ca.a + (cb.a - ca.a) * t
        )
    }
}

private extension UIColor {
    var rgba: (r: Double, g: Double, b: Double, a: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }
}

/// Central palette for Epic World Travel & Tours — the port of `app_ui_kit`'s
/// `AppColors`. The brand green `primary` (#4C8139) must stay consistent
/// across the whole app; always reference these instead of raw hex values.
enum AppColors {
    // ---- Brand ----
    static let primary = Color(0xFF4C8139)
    static let primaryDark = Color(0xFF3A6429)
    static let primaryLight = Color(0xFF6FA257)
    /// Soft tint used for selected chips, icon backgrounds and subtle fills.
    static let primarySurface = Color(0xFFEAF2E5)
    /// Warm accent (matches the airplane in the logo) for highlights / badges.
    static let accent = Color(0xFFE8A33D)

    // ---- Neutrals ----
    static let headerDark = Color(0xFF15170F)
    static let background = Color(0xFFF6F8F4)
    static let surface = Color(0xFFFFFFFF)
    static let textPrimary = Color(0xFF1C2417)
    static let textSecondary = Color(0xFF6B7669)
    static let textTertiary = Color(0xFF9AA394)
    /// Input placeholder / hint text.
    static let textPlaceholder = Color(0xFFC3C9BB)
    static let border = Color(0xFFE4E8DF)
    static let divider = Color(0xFFEDF0E9)
    /// Softer separator used for in-card seams / dashed lines.
    static let dividerLight = Color(0xFFF3F6F0)

    // ---- Semantic ----
    static let success = Color(0xFF2E7D32)
    static let warning = Color(0xFFE8A33D)
    static let error = Color(0xFFC0392B)
    static let info = Color(0xFF2D7DD2)

    // ---- Other accents ----
    static let violet = Color(0xFF8B5CF6)
    static let teal = Color(0xFF14B8A6)
    static let rose = Color(0xFFEC4899)

    // ---- Gradients ----
    static let primaryGradient = LinearGradient(
        colors: [primary, primaryLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heroGradient = LinearGradient(
        colors: [Color(0xFF4C8139), Color(0xFF2F5C23)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Branded green → page-background fade behind the home header.
    static let homeHeaderGradient = LinearGradient(
        stops: [
            .init(color: Color(0xFF2F7D3E), location: 0.0),
            .init(color: Color(0xFF77B587), location: 0.5),
            .init(color: Color(0xFFF6F8F4), location: 1.0),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

/// Flutter's Material `Colors` palette — the members this app uses, with
/// Flutter's exact values.
enum Colors {
    static let transparent = Color.clear
    static let white = Color(0xFFFFFFFF)
    static let black = Color(0xFF000000)

    static let white10 = Color(0x1AFFFFFF)
    static let white12 = Color(0x1FFFFFFF)
    static let white24 = Color(0x3DFFFFFF)
    static let white30 = Color(0x4DFFFFFF)
    static let white38 = Color(0x62FFFFFF)
    static let white54 = Color(0x8AFFFFFF)
    static let white60 = Color(0x99FFFFFF)
    static let white70 = Color(0xB3FFFFFF)
    static let black12 = Color(0x1F000000)
    static let black26 = Color(0x42000000)
    static let black38 = Color(0x61000000)
    static let black45 = Color(0x73000000)
    static let black54 = Color(0x8A000000)
    static let black87 = Color(0xDD000000)

    static let red = Color(0xFFF44336)
    static let green = Color(0xFF4CAF50)
    static let blue = Color(0xFF2196F3)
    static let amber = Color(0xFFFFC107)
    static let orange = Color(0xFFFF9800)
    static let deepOrange = Color(0xFFFF5722)
    static let yellow = Color(0xFFFFEB3B)
    static let teal = Color(0xFF009688)
    static let purple = Color(0xFF9C27B0)
    static let indigo = Color(0xFF3F51B5)
    static let pink = Color(0xFFE91E63)
    static let cyan = Color(0xFF00BCD4)
    static let lightBlue = Color(0xFF03A9F4)
    static let lightGreen = Color(0xFF8BC34A)
    static let brown = Color(0xFF795548)
    static let blueGrey = Color(0xFF607D8B)

    static let grey = Color(0xFF9E9E9E)
    static let grey50 = Color(0xFFFAFAFA)
    static let grey100 = Color(0xFFF5F5F5)
    static let grey200 = Color(0xFFEEEEEE)
    static let grey300 = Color(0xFFE0E0E0)
    static let grey400 = Color(0xFFBDBDBD)
    static let grey500 = Color(0xFF9E9E9E)
    static let grey600 = Color(0xFF757575)
    static let grey700 = Color(0xFF616161)
    static let grey800 = Color(0xFF424242)
    static let grey900 = Color(0xFF212121)
}

/// Flutter `Alignment` → SwiftUI `UnitPoint`, for porting gradients.
///
/// | Dart                     | Swift            |
/// |--------------------------|------------------|
/// | `Alignment.topLeft`      | `.topLeading`    |
/// | `Alignment.topCenter`    | `.top`           |
/// | `Alignment.bottomRight`  | `.bottomTrailing`|
/// | `Alignment(x, y)`        | `UnitPoint.alignment(x, y)` |
extension UnitPoint {
    /// Flutter `Alignment(x, y)` with x, y in -1…1.
    static func alignment(_ x: Double, _ y: Double) -> UnitPoint {
        UnitPoint(x: (x + 1) / 2, y: (y + 1) / 2)
    }
}
