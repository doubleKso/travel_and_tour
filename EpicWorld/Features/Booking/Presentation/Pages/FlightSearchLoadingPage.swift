// Port of lib/features/booking/presentation/pages/flight_search_loading_page.dart

import SwiftUI

/// FLIGHT SEARCH LOADING — the branded interstitial shown after the user taps
/// "Search" on the home page.
///
/// Pushed as a *transparent*, frosted-blur overlay over the search-results
/// screen behind it: the Epic World logo's yellow globe sits at the centre
/// while the logo's own airplane orbits it, then breaks orbit and spirals off
/// the ring as the search finishes. A rotating status caption, a boarding-pass
/// style route chip (IATA codes) and a slim flight-progress bar sit below.
/// After ~3s the loader pops, revealing the results already rendered beneath.
///
/// `AppRouter` draws this route as the transparent overlay (auto_route
/// `CustomRoute(opaque: false)` with a fade).
struct FlightSearchLoadingPage: View {
    let from: LocationModel
    let to: LocationModel

    @Environment(AppRouter.self) private var router

    /// Start of the master timeline (`_timeline.forward()` in `initState`).
    @State private var start = Date()
    @State private var statusIndex = 0

    init(from: LocationModel, to: LocationModel) {
        self.from = from
        self.to = to
    }

    // Keep the branded transition visible without making a completed search feel
    // slow. The results page continues to show its own loader if the API needs
    // longer than this animation.
    private static let totalDuration: Double = 3

    static let statuses = [
        "Searching for flights…",
        "Comparing airlines & fares…",
        "Finding the best routes…",
        "Almost ready…",
    ]

    /// Dart `_onTick`: the status shown at timeline value `value` (0…1).
    static func statusIndex(at value: Double) -> Int {
        let raw = min(max(value * Double(statuses.count), 0), Double(statuses.count - 1))
        return Int(raw.rounded(.down))
    }

    /// The master timeline's value (0…1) at `date`.
    private func timelineValue(at date: Date) -> Double {
        min(max(date.timeIntervalSince(start) / Self.totalDuration, 0), 1)
    }

    var body: some View {
        // Non-dismissible: the user waits for the search to finish.
        ZStack {
            // Frosted-glass blur: the page behind stays visible but softly
            // blurred (a light white tint, not an opaque cover).
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            Colors.white.withValues(alpha: 0.45)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { _ in Spacer(minLength: 0) } // Spacer(flex: 3)

                // Yellow globe (logo) with the logo's airplane orbiting it.
                TimelineView(.animation) { context in
                    let orbit = OrbitState.at(timelineValue(at: context.date))
                    ZStack {
                        // Dashed orbit ring + accent trail behind plane.
                        Canvas { canvas, size in
                            OrbitPainter(
                                angle: orbit.angle,
                                showTrail: orbit.onOrbit,
                                trailFade: orbit.trailOpacity
                            )
                            .paint(canvas, size)
                        }
                        .frame(width: 210, height: 210)

                        // The logo's yellow world.
                        AppImage(AppAssets.logoGlobe, width: 96)

                        // The logo's own airplane, orbiting the globe.
                        AppImage(AppAssets.logoPlane, width: 32)
                            .opacity(orbit.opacity)
                            .scaleEffect(orbit.scale)
                            .rotationEffect(.radians(orbit.angle + 3 * Double.pi / 4))
                            .offset(x: orbit.offset.width, y: orbit.offset.height)
                    }
                    .frame(width: 210, height: 210)
                }
                .frame(width: 210, height: 210)

                VGap(40)

                // Rotating status line.
                ZStack {
                    Text(Self.statuses[statusIndex])
                        .textStyle(AppTypography.body(16, weight: .w700, color: AppColors.textPrimary))
                        .multilineTextAlignment(.center)
                        .id(statusIndex)
                        .transition(.opacity)
                }
                .animation(.linear(duration: 0.3), value: statusIndex)
                VGap(18)

                // Boarding-pass style route chip (IATA codes).
                RouteChip(from: from.code, to: to.code)

                ForEach(0..<2, id: \.self) { _ in Spacer(minLength: 0) } // Spacer(flex: 2)

                // Flight-progress bar (gradient fill + glowing dot).
                TimelineView(.animation) { context in
                    FlightProgressBar(progress: timelineValue(at: context.date))
                }
                .frame(width: 190, height: 12)
                Spacer(minLength: 0) // Spacer(flex: 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .popScope(canPop: false)
        .task {
            // `_onTick` → status changes at each quarter of the timeline, then
            // `_onStatus(completed)` removes the loader to reveal the results
            // already rendered beneath. Uses pop() (not maybePop) so the
            // popScope(canPop: false) guard doesn't block the dismissal.
            for index in 1..<Self.statuses.count {
                let at = Double(index) / Double(Self.statuses.count) * Self.totalDuration
                let wait = at - Date().timeIntervalSince(start)
                if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
                if Task.isCancelled { return }
                if Self.statusIndex(at: timelineValue(at: Date())) != statusIndex {
                    statusIndex = Self.statusIndex(at: timelineValue(at: Date()))
                }
            }
            let remaining = Self.totalDuration - Date().timeIntervalSince(start)
            if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
            if Task.isCancelled { return }
            router.pop()
        }
    }
}

/// Computed plane state for a given timeline value — encapsulates the two
/// phases: orbiting the globe, then breaking orbit and flying outward.
private struct OrbitState {
    let offset: CGSize
    let angle: Double
    let scale: Double
    let opacity: Double
    let onOrbit: Bool
    let trailOpacity: Double

    static let orbitRadius: Double = 78
    static let turns: Double = 2 // whole loops before it breaks orbit
    static let breakPoint: Double = 0.72 // orbit for the first 72% of time
    static let startAngle: Double = -Double.pi / 2 // start at the top

    private static let easeInOut = LoaderCubic(0.42, 0.0, 0.58, 1.0)
    private static let easeInCubic = LoaderCubic(0.55, 0.055, 0.675, 0.19)

    static func at(_ t: Double) -> OrbitState {
        if t <= breakPoint {
            // Phase 1 — smooth continuous orbit around the globe.
            let p = easeInOut.transform(t / breakPoint)
            let angle = startAngle + p * turns * 2 * Double.pi
            return OrbitState(
                offset: CGSize(width: orbitRadius * cos(angle), height: orbitRadius * sin(angle)),
                angle: angle,
                scale: 1,
                opacity: 1,
                onOrbit: true,
                trailOpacity: 0.9
            )
        }

        // Phase 2 — keep circling in the same direction while spiralling outward,
        // so the plane loops once more and flies off the ring, fading as it goes.
        let fp = min(max((t - breakPoint) / (1 - breakPoint), 0), 1)
        let eased = easeInCubic.transform(fp)
        let angle = startAngle + turns * 2 * Double.pi + fp * 2 * Double.pi
        let radius = orbitRadius + eased * 280
        return OrbitState(
            offset: CGSize(width: radius * cos(angle), height: radius * sin(angle)),
            angle: angle,
            scale: 1 + eased * 0.12,
            opacity: min(max(1 - (fp - 0.5) / 0.5, 0), 1),
            onOrbit: false,
            trailOpacity: 0
        )
    }
}

/// Dashed orbit ring plus a glowing accent trail that follows the plane while
/// it is still on orbit.
private struct OrbitPainter {
    let angle: Double
    let showTrail: Bool
    let trailFade: Double

    func paint(_ canvas: GraphicsContext, _ size: CGSize) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = CGFloat(OrbitState.orbitRadius)

        // Faint dashed ring (subtle brand green on the light backdrop).
        let ringStyle = StrokeStyle(lineWidth: 1.5, lineCap: .round)
        let ringColor = AppColors.primary.withValues(alpha: 0.18)
        let dashes = 60
        for i in stride(from: 0, to: dashes, by: 2) {
            let a1 = Double(i) / Double(dashes) * 2 * Double.pi
            let a2 = Double(i + 1) / Double(dashes) * 2 * Double.pi
            var arc = Path()
            arc.addArc(center: c, radius: radius, startAngle: .radians(a1), endAngle: .radians(a2), clockwise: false)
            canvas.stroke(arc, with: .color(ringColor), style: ringStyle)
        }

        // Glowing accent trail sweeping up to the plane's current angle.
        if showTrail && trailFade > 0 {
            let sweep = 1.1 * Double.pi // length of the comet tail
            var trail = Path()
            trail.addArc(
                center: c,
                radius: radius,
                startAngle: .radians(angle - sweep),
                endAngle: .radians(angle),
                clockwise: false
            )
            // SweepGradient(startAngle: angle - sweep, endAngle: angle) with
            // clamping: transparent before the tail, full colour from the plane on.
            let gradient = Gradient(stops: [
                .init(color: AppColors.accent.withValues(alpha: 0.0), location: 0),
                .init(color: AppColors.accent.withValues(alpha: trailFade), location: sweep / (2 * Double.pi)),
                .init(color: AppColors.accent.withValues(alpha: 0.0), location: 1),
            ])
            canvas.stroke(
                trail,
                with: .conicGradient(gradient, center: c, angle: .radians(angle - sweep)),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
        }
    }
}

/// Boarding-pass style route chip: two IATA-code badges joined by a dashed line
/// with a small plane riding it — e.g. `[RGN] ··✈·· [MDL]`.
private struct RouteChip: View {
    let from: String
    let to: String

    var body: some View {
        HStack(spacing: 0) {
            codeBadge(from)
            HGap(10)
            DashedConnector()
            HGap(10)
            codeBadge(to)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .boxDecoration(
            color: AppColors.surface,
            radius: 16,
            borderColor: AppColors.border,
            shadows: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: Offset(0, 4)
                ),
            ]
        )
    }

    private func codeBadge(_ code: String) -> some View {
        Text(code)
            .textStyle(AppTypography.heading(16, weight: .w800, color: AppColors.primaryDark, letterSpacing: 1.0))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .boxDecoration(color: AppColors.primarySurface, radius: 9)
    }
}

/// A short dashed line with a small accent plane bubble in the middle.
private struct DashedConnector: View {
    var body: some View {
        ZStack {
            Canvas { canvas, size in
                // Dart `_DashPainter`.
                let y = size.height / 2
                let color = AppColors.textTertiary.withValues(alpha: 0.5)
                var x: CGFloat = 0
                while x < size.width {
                    var line = Path()
                    line.move(to: CGPoint(x: x, y: y))
                    line.addLine(to: CGPoint(x: x + 3, y: y))
                    canvas.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    x += 6
                }
            }
            Icon(Icons.flight, size: 13, color: Colors.white)
                .rotationEffect(.radians(Double.pi / 2))
                .frame(width: 22, height: 22)
                .background(Circle().fill(AppColors.accent))
        }
        .frame(width: 54, height: 22)
    }
}

/// Slim flight-progress bar: a rounded track with a primary→accent gradient
/// fill (no leading marker).
private struct FlightProgressBar: View {
    let progress: Double

    var body: some View {
        let p = min(max(progress, 0), 1)
        ZStack(alignment: .leading) {
            // Track.
            RoundedRectangle(cornerRadius: 6)
                .fill(AppColors.border)
                .frame(height: 6)
            // Gradient fill.
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [AppColors.primaryLight, AppColors.accent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 190 * p, height: 6)
        }
        .frame(width: 190, height: 12)
    }
}

/// Flutter's `Cubic(a, b, c, d)` curve — `Curves.easeInOut` and
/// `Curves.easeInCubic` — evaluated with Flutter's own bisection.
private struct LoaderCubic {
    let a: Double
    let b: Double
    let c: Double
    let d: Double

    init(_ a: Double, _ b: Double, _ c: Double, _ d: Double) {
        self.a = a
        self.b = b
        self.c = c
        self.d = d
    }

    private func evaluate(_ p: Double, _ q: Double, _ m: Double) -> Double {
        3 * p * (1 - m) * (1 - m) * m + 3 * q * (1 - m) * m * m + m * m * m
    }

    func transform(_ t: Double) -> Double {
        if t <= 0 || t >= 1 { return min(max(t, 0), 1) }
        var start = 0.0
        var end = 1.0
        while true {
            let midpoint = (start + end) / 2
            let estimate = evaluate(a, c, midpoint)
            if abs(t - estimate) < 0.001 { return evaluate(b, d, midpoint) }
            if estimate < t { start = midpoint } else { end = midpoint }
        }
    }
}
