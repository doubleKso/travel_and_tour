// Port of lib/features/visa/presentation/widgets/visa_section_heading.dart

import SwiftUI

/// Centred section heading used across the visa screens: a small coloured
/// eyebrow, a two-tone title (`title` in ink + `highlight` in an accent), and
/// an optional supporting line.
struct VisaSectionHeading: View {
    let eyebrow: String
    let title: String
    let highlight: String
    let subtitle: String?
    let eyebrowColor: Color
    let highlightColor: Color

    @Environment(\.visaMediaWidth) private var mediaWidth

    init(
        eyebrow: String,
        title: String,
        highlight: String,
        subtitle: String? = nil,
        eyebrowColor: Color = AppColors.accent,
        highlightColor: Color = AppColors.primary
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.highlight = highlight
        self.subtitle = subtitle
        self.eyebrowColor = eyebrowColor
        self.highlightColor = highlightColor
    }

    var body: some View {
        let wide = mediaWidth >= 700
        let titleSize: CGFloat = wide ? 30 : 25

        VStack(spacing: 0) {
            Text(eyebrow.uppercased())
                .textStyle(AppTypography.body(12, weight: .w800, color: eyebrowColor, letterSpacing: 0.7))
                .multilineTextAlignment(.center)
            VGap(5)
            (
                Text(title + " ").styled(AppTypography.heading(titleSize))
                    + Text(highlight).styled(AppTypography.heading(titleSize, color: highlightColor))
            )
            .multilineTextAlignment(.center)
            if let subtitle {
                VGap(7)
                Text(subtitle)
                    .textStyle(AppTypography.body(14, color: AppColors.textSecondary, height: 1.45))
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - MediaQuery width

/// `MediaQuery.sizeOf(context).width` for the visa screens — the window
/// width, which the visa pages publish from their root `GeometryReader` so the
/// heading and the country screen's cards can pick their wide layouts.
private struct VisaMediaWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var visaMediaWidth: CGFloat {
        get { self[VisaMediaWidthKey.self] }
        set { self[VisaMediaWidthKey.self] = newValue }
    }
}
