// Port of lib/features/visa/presentation/widgets/visa_reveal.dart

import SwiftUI

/// Automatic entrance animation — fades, slides up, and scales its `child` in.
/// `index` × `stagger` delays the start so a row/grid reveals one-by-one.
///
/// Shared by the Visa screen and the country screen so both halves of the
/// feature animate identically.
struct VisaReveal<Content: View>: View {
    let index: Int
    let stagger: Duration
    let child: Content

    @State private var progress: Double = 0

    init(
        index: Int = 0,
        stagger: Duration = .milliseconds(70),
        @ViewBuilder child: () -> Content
    ) {
        self.index = index
        self.stagger = stagger
        self.child = child()
    }

    var body: some View {
        child
            .scaleEffect(0.94 + 0.06 * progress)
            .modifier(VisaRevealSlide(progress: progress))
            .opacity(progress)
            .task {
                // Kick off after a per-index delay so items reveal in sequence.
                try? await Task.sleep(for: stagger * index)
                guard !Task.isCancelled else { return }
                // Curves.easeOutCubic over 480ms.
                withAnimation(.timingCurve(0.215, 0.61, 0.355, 1, duration: 0.48)) {
                    progress = 1
                }
            }
    }
}

/// `SlideTransition(position: Tween(begin: Offset(0, 0.16), end: Offset.zero))`:
/// a vertical offset measured in the child's own height.
private struct VisaRevealSlide: GeometryEffect {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(translationX: 0, y: (1 - progress) * 0.16 * size.height)
        )
    }
}
