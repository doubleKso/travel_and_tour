// Port of lib/features/booking/presentation/widgets/checkout_step_header.dart
import SwiftUI

/// Shared green header + horizontal step tracker used across the checkout flow
/// (search results, passenger details, payment, booking confirmed) so every
/// step wears the same heading.
///
/// Renders either a `FROM ✈ TO` route (when `fromCode`/`toCode` are given) or a
/// plain `title`. There is no calendar / date action.
struct CheckoutStepHeader: View {
    let stage: BookingStage
    let fromCode: String?
    let toCode: String?
    let title: String?
    let subtitle: String?
    let showBack: Bool
    let onBack: (() -> Void)?

    /// When false the horizontal step tracker (and its divider) is omitted —
    /// used by the reservation flow, which isn't part of the numbered steps.
    let showTracker: Bool

    @Environment(AppRouter.self) private var router

    init(
        stage: BookingStage,
        fromCode: String? = nil,
        toCode: String? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        showBack: Bool = true,
        onBack: (() -> Void)? = nil,
        showTracker: Bool = true
    ) {
        self.stage = stage
        self.fromCode = fromCode
        self.toCode = toCode
        self.title = title
        self.subtitle = subtitle
        self.showBack = showBack
        self.onBack = onBack
        self.showTracker = showTracker
    }

    var body: some View {
        VStack(spacing: 0) {
            // Green gradient header — back button, centred route/title, no action.
            // `topPad` (MediaQuery padding.top) is the safe area the gradient
            // extends under; the row itself sits 6pt below it.
            HStack(alignment: .center, spacing: 0) {
                if showBack {
                    Button {
                        if let onBack {
                            onBack()
                        } else {
                            Task { await router.maybePop() }
                        }
                    } label: {
                        Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(width: 44)
                } else {
                    HGap(44)
                }
                titleColumn
                    .frame(maxWidth: .infinity)
                HGap(44)
            }
            .padding(6, 6, 6, 16)
            .frame(maxWidth: .infinity)
            .background(AppColors.heroGradient.ignoresSafeArea(edges: .top))
            // Horizontal step tracker — same left/right inset as the page cards.
            if showTracker {
                BookingProgressTracker(current: stage)
                    .padding(AppSpacing.screenH, 10, AppSpacing.screenH, 10)
                    .frame(maxWidth: .infinity)
                    .background(AppColors.surface)
                MaterialDivider(height: 1, color: AppColors.border)
            }
        }
    }

    private var titleColumn: some View {
        VStack(spacing: 0) {
            if let fromCode, let toCode {
                HStack(spacing: 0) {
                    Text(fromCode)
                        .textStyle(AppTypography.heading(18, color: Colors.white))
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Icon(Icons.flight_takeoff_rounded, size: 17, color: Colors.white)
                        .padding(.horizontal, 8)
                    Text(toCode)
                        .textStyle(AppTypography.heading(18, color: Colors.white))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            } else {
                Text(title ?? "")
                    .textStyle(AppTypography.heading(20, color: Colors.white))
                    .multilineTextAlignment(.center)
            }
            if let subtitle {
                VGap(3)
                Text(subtitle)
                    .textStyle(AppTypography.body(
                        11.5,
                        weight: .w500,
                        color: Colors.white.withValues(alpha: 0.85)
                    ))
                    .multilineTextAlignment(.center)
            }
        }
    }
}
