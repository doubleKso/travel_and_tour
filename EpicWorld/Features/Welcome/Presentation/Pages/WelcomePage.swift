// Port of lib/features/welcome/presentation/pages/welcome_page.dart
import SwiftUI

/// WELCOME / ONBOARDING — first screen the user sees.
///
/// Structure (top → bottom):
///   1. Brand row        — Epic World logo + IATA accreditation badge
///   2. Hero illustration — the airplane-window artwork (h1-airplane.png)
///   3. Headline block    — copy + "Get Started" CTA on the plain surface
///
/// The CTA uses the brand `AppColors.primary` (green); "Go Explore!" is
/// underlined with a hand-drawn `AppColors.accent` (yellow) swoosh.
struct WelcomePage: View {
    /// Fired when the user taps "Get Started". Defaults to replacing this page
    /// with the app shell; pass a callback to intercept (e.g. in a test).
    let onGetStarted: (() -> Void)?

    init(onGetStarted: (() -> Void)? = nil) {
        self.onGetStarted = onGetStarted
    }

    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(spacing: 0) {
            // 1. Brand + accreditation logos.
            HStack(spacing: 0) {
                AppImage(AppAssets.brandLogo, height: 36)
                HGap(14)
                Rectangle()
                    .fill(AppColors.border)
                    .frame(width: 1, height: 34)
                HGap(14)
                AppImage(AppAssets.iataBadge, height: 46)
            }
            .padding(24, 18, 24, 0)

            // 2. Hero illustration — the airplane-window artwork.
            AppImage(AppAssets.welcomeAirplane, fit: .contain)
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 3. Headline, copy and the CTA (on the plain surface, no card).
            VStack(spacing: 0) {
                // Row 1 — kept on a single line (scales to fit the width).
                Text(LocaleKeys.welcome_journey_beyond.tr())
                    .textStyle(AppTypography.heading(
                        34,
                        weight: .w900,
                        color: AppColors.textPrimary,
                        height: 1.15,
                        letterSpacing: -0.8
                    ))
                    .lineLimit(1)
                    .minimumScaleFactor(0.1)
                VGap(8)
                // Row 2 — emphasised, with the yellow hand-drawn swoosh.
                CurvedUnderline("Imagination")
                VGap(14)
                Text(LocaleKeys.welcome_we_can_easily_help_you_to.tr())
                    .textStyle(AppTypography.body(13.5, color: AppColors.textSecondary, height: 1.5))
                    .multilineTextAlignment(.center)
                VGap(28)
                Button {
                    if let onGetStarted {
                        onGetStarted()
                    } else {
                        router.replaceAll([.mainShell])
                    }
                } label: {
                    Text(LocaleKeys.welcome_get_started.tr())
                        .textStyle(AppTypography.heading(16, color: Colors.white))
                }
                .buttonStyle(ElevatedButtonStyle(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumHeight: 56,
                    cornerRadius: 30,
                    elevation: 0
                ))
                .frame(height: 56)
            }
            .padding(28, 8, 28, 24)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.surface.ignoresSafeArea())
    }
}

/// A heading line with a hand-drawn yellow swoosh underline sized to the text.
private struct CurvedUnderline: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        // FittedBox(scaleDown) + IntrinsicWidth: the swoosh spans exactly the
        // word's width, and the word shrinks rather than clips when it is wider
        // than the screen.
        VStack(spacing: 0) {
            // Extra right padding prevents the last glyph being clipped.
            Text(text)
                .textStyle(AppTypography.heading(
                    35,
                    weight: .w900,
                    color: AppColors.textPrimary,
                    height: 1.2
                ))
                .lineLimit(1)
                .minimumScaleFactor(0.1)
                .multilineTextAlignment(.center)
                .padding(.trailing, 16)
            // SizedBox(height: 4) and SizedBox(width: double.infinity,
            // height: 9) add no intrinsic width, so the column is exactly as
            // wide as the word; the swoosh is drawn over the 9pt slot.
            Color.clear.frame(width: 0, height: 4)
            Color.clear.frame(width: 0, height: 9)
        }
        .overlay(alignment: .bottom) {
            SwooshShape()
                .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(height: 9)
        }
    }
}

/// Paints a single gentle yellow curve — the underline swoosh.
private struct SwooshShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.03, y: rect.height * 0.30))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.97, y: rect.height * 0.20),
            control: CGPoint(x: rect.width * 0.5, y: rect.height * 1.15)
        )
        return path
    }
}
