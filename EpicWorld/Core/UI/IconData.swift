import SwiftUI

/// A Material icon glyph — Flutter's `IconData`. The code points come from
/// Flutter's `Icons` (see the generated `Icons.swift`) and are drawn from the
/// MaterialIcons font Flutter itself ships, so every icon matches pixel for
/// pixel.
struct IconData: Hashable {
    let codePoint: UInt32
    init(_ codePoint: UInt32) { self.codePoint = codePoint }

    var glyph: String { String(UnicodeScalar(codePoint).map(Character.init) ?? " ") }

    /// PostScript name of the bundled font (Resources/Fonts/MaterialIcons-Regular.otf).
    static let fontName = "MaterialIcons-Regular"
}

/// Flutter's `Icon(Icons.x, size: 24, color: …)`.
///
/// ```swift
/// Icon(Icons.home_rounded, size: 25, color: AppColors.primary)
/// ```
/// Without a colour it inherits the surrounding `foregroundStyle`, the way a
/// Flutter `Icon` inherits its `IconTheme`.
struct Icon: View {
    let icon: IconData
    var size: CGFloat = 24
    var color: Color? = nil

    init(_ icon: IconData, size: CGFloat = 24, color: Color? = nil) {
        self.icon = icon
        self.size = size
        self.color = color
    }

    var body: some View {
        let glyph = Text(icon.glyph)
            .font(.custom(IconData.fontName, fixedSize: size))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
        if let color {
            glyph.foregroundStyle(color)
        } else {
            glyph
        }
    }
}
