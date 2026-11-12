import CoreGraphics

/// Spacing scale (8pt grid) — the port of `app_ui_kit`'s `AppSpacing`.
enum AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let section: CGFloat = 40

    /// Default horizontal screen padding.
    static let screenH: CGFloat = 20
}
