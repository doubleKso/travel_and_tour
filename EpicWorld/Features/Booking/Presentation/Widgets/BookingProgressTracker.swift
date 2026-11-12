// Port of lib/features/booking/presentation/widgets/booking_progress_tracker.dart
import SwiftUI

/// Horizontal step indicator for the checkout journey:
/// **Search → Detail → Confirm → Payment → Completed**.
///
/// Numbered circles joined by dotted connectors: completed steps are filled
/// green with a check, the current step is filled green with its number, and
/// upcoming steps are outlined (white fill, green ring, green number). The
/// connector dots turn green up to the current step.
///
/// ```swift
/// BookingProgressTracker(current: container.flightBookingBloc.state.stage)
/// ```
struct BookingProgressTracker: View {
    let current: BookingStage

    /// Optional: tap a *completed* step to jump back to it.
    let onStepTapped: ((BookingStage) -> Void)?

    init(current: BookingStage, onStepTapped: ((BookingStage) -> Void)? = nil) {
        self.current = current
        self.onStepTapped = onStepTapped
    }

    private static let stages: [BookingStage] = [
        .search,
        .detail,
        .confirmation,
        .payment,
        .completed,
    ]
    private static let markerRow: CGFloat = 32

    var body: some View {
        let currentIndex = Self.stages.firstIndex(of: current) ?? -1

        // LayoutBuilder → GeometryReader. The row's height is fixed by its
        // children (marker row + gap + label + vertical padding), so the
        // reader gets that height explicitly instead of expanding.
        GeometryReader { geometry in
            let connectorWidth: CGFloat = geometry.size.width < 360 ? 6.0 : 14.0
            HStack(alignment: .top, spacing: 0) {
                ForEach(0..<Self.stages.count, id: \.self) { i in
                    StepNode(
                        index: i,
                        stage: Self.stages[i],
                        currentIndex: currentIndex,
                        markerRow: Self.markerRow,
                        onTap: onStepTapped
                    )
                    .frame(maxWidth: .infinity)
                    if i < Self.stages.count - 1 {
                        DottedConnector(
                            filled: i < currentIndex,
                            centerY: Self.markerRow / 2
                        )
                        .frame(width: connectorWidth)
                    }
                }
            }
            .padding(horizontal: 8, vertical: 4)
        }
        .frame(height: Self.markerRow + 6 + 14 + 8)
    }
}

private struct StepNode: View {
    let index: Int
    let stage: BookingStage
    let currentIndex: Int
    let markerRow: CGFloat
    let onTap: ((BookingStage) -> Void)?

    var body: some View {
        let isCompleted = index < currentIndex
        let isCurrent = index == currentIndex
        let isUpcoming = index > currentIndex
        let isFilled = isCompleted || isCurrent

        let labelColor = isUpcoming ? AppColors.textTertiary : AppColors.primaryDark

        let canTap = isCompleted && onTap != nil

        VStack(spacing: 0) {
            disc(isCompleted: isCompleted, isCurrent: isCurrent, isFilled: isFilled)
                .frame(height: markerRow)
            VGap(6)
            Text(stage.label)
                .textStyle(AppTypography.body(
                    10.5,
                    weight: isCurrent ? .w700 : .w500,
                    color: labelColor,
                    letterSpacing: 0.2
                ))
                .lineLimit(1)
                .minimumScaleFactor(0.1)
                .frame(height: 14)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard canTap else { return }
            onTap?(stage)
        }
    }

    /// AnimatedContainer(duration: 250ms, curve: easeOut).
    private func disc(isCompleted: Bool, isCurrent: Bool, isFilled: Bool) -> some View {
        ZStack {
            if isCompleted {
                Icon(Icons.check_rounded, size: 15, color: Colors.white)
            } else {
                Text("\(index + 1)")
                    .textStyle(AppTypography.body(
                        12.5,
                        weight: .w700,
                        color: isFilled ? Colors.white : AppColors.primary
                    ))
            }
        }
        .frame(width: isCurrent ? 30 : 26, height: isCurrent ? 30 : 26)
        .boxDecoration(
            color: isFilled ? nil : AppColors.surface,
            gradient: isFilled ? AppColors.primaryGradient : nil,
            circle: true,
            borderColor: isFilled ? nil : AppColors.primary,
            borderWidth: 1.5,
            shadows: isCurrent
                ? [
                    BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.30),
                        blurRadius: 8,
                        offset: Offset(0, 2)
                    ),
                ]
                : []
        )
        .animation(.easeOut(duration: 0.25), value: currentIndex)
    }
}

/// A dotted horizontal connector, aligned to the marker centres. Dots are green
/// for completed segments, light grey for upcoming ones.
private struct DottedConnector: View {
    let filled: Bool
    let centerY: CGFloat

    var body: some View {
        DotsPainter(color: filled ? AppColors.primary : AppColors.border)
            .frame(height: 3)
            .padding(.top, centerY - 1.5)
            .padding(.leading, 3)
            .padding(.trailing, 3)
    }
}

private struct DotsPainter: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let gap: CGFloat = 6.0
            let r: CGFloat = 1.6
            let y = size.height / 2
            var x = r
            while x <= size.width {
                context.fill(
                    Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                    with: .color(color)
                )
                x += gap
            }
        }
    }
}
