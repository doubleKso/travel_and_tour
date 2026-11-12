import SwiftUI

/// Lightweight text-based stand-in for the Epic World logo — the port of
/// lib/core/presentation/widgets/brand_logo.dart.
struct BrandLogo: View {
    var height: CGFloat = 34
    var compact = false

    var body: some View {
        HStack(spacing: 0) {
            Icon(Icons.public, size: height * 0.6, color: Colors.white)
                .frame(width: height, height: height)
                .background(Circle().fill(AppColors.primaryGradient))
            if !compact {
                HGap(8)
                VStack(alignment: .leading, spacing: 0) {
                    Text(LocaleKeys.common_epic_world.tr())
                        .textStyle(AppTypography.heading(height * 0.52, color: AppColors.primary, letterSpacing: 0.5))
                    Text(LocaleKeys.common_travel_tours.tr())
                        .textStyle(AppTypography.body(height * 0.30, weight: .w600, color: AppColors.accent))
                }
            }
        }
    }
}

/// Branded airline logo tile — the port of
/// lib/core/presentation/widgets/airline_brand_badge.dart.
struct AirlineBrandBadge: View {
    let operatorName: String
    var size: CGFloat = 42

    init(operator operatorName: String, size: CGFloat = 42) {
        self.operatorName = operatorName
        self.size = size
    }

    // operator-name fragment -> (brand colour, monogram)
    private static let brands: [(String, Color, String)] = [
        ("air kbz", Color(0xFF1668B3), "KBZ"),
        ("mai airway", Color(0xFFC0392B), "MAI"),
        ("air thanlwin", Color(0xFF0E8F8F), "ATL"),
        ("jj express", Color(0xFF2E7D32), "JJ"),
        ("elite express", Color(0xFF6A3DB5), "EE"),
        ("mandalar minn", Color(0xFFD98A2B), "MM"),
    ]

    private var brand: (Color, String) {
        let key = operatorName.lowercased()
        for (fragment, color, code) in Self.brands where key.contains(fragment) {
            return (color, code)
        }
        let initial = operatorName.first.map { String($0).uppercased() } ?? "?"
        return (AppColors.primary, initial)
    }

    var body: some View {
        let (color, code) = brand
        Text(code)
            .textStyle(AppTypography.heading(code.count > 2 ? size * 0.22 : size * 0.30, color: Colors.white))
            .frame(width: size - 12, height: size - 12)
            .background(Circle().fill(color))
            .frame(width: size, height: size)
            .boxDecoration(color: Colors.white, radius: 12, borderColor: AppColors.border)
    }
}

/// Branded waiting indicator: the Epic World globe with the logo's plane
/// orbiting it — the port of lib/core/presentation/widgets/flight_orbit_loader.dart.
///
/// One quick, constant-speed lap per `turn`, looping for as long as the wait
/// lasts. The rotation is linear on purpose — an eased curve would visibly
/// stall at the top of every lap.
struct FlightOrbitLoader: View {
    var size: CGFloat = 128
    var turn: Duration = .milliseconds(1100)

    @State var start = Date()

    var body: some View {
        TimelineView(.animation) { context in
            let period = max(turn.timeInterval, 0.001)
            let progress = context.date.timeIntervalSince(start).truncatingRemainder(dividingBy: period) / period
            // Start at the top and sweep one full turn per cycle.
            let angle = -Double.pi / 2 + progress * 2 * Double.pi
            let radius = size * 0.37
            ZStack {
                Canvas { canvas, canvasSize in
                    drawRing(canvas, size: canvasSize, angle: angle, radius: radius)
                }
                AppImage(AppAssets.logoGlobe, width: size * 0.46)
                AppImage(AppAssets.logoPlane, width: size * 0.16)
                    // The sprite points up-left, so nose-to-travel needs a
                    // three-quarter turn on top of the orbit angle.
                    .rotationEffect(.radians(angle + 3 * Double.pi / 4))
                    .offset(x: radius * cos(angle), y: radius * sin(angle))
            }
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }

    /// Faint dashed orbit ring with a glowing accent trail running up to the
    /// plane — the comet tail is what makes the lap read as motion.
    private func drawRing(_ canvas: GraphicsContext, size canvasSize: CGSize, angle: Double, radius: CGFloat) {
        let centre = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let dashes = 60
        for i in stride(from: 0, to: dashes, by: 2) {
            let start = Double(i) / Double(dashes) * 2 * Double.pi
            let end = Double(i + 1) / Double(dashes) * 2 * Double.pi
            var arc = Path()
            arc.addArc(center: centre, radius: radius, startAngle: .radians(start), endAngle: .radians(end), clockwise: false)
            canvas.stroke(arc, with: .color(AppColors.primary.withValues(alpha: 0.18)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }

        let sweep = 1.1 * Double.pi // length of the comet tail
        var trail = Path()
        trail.addArc(center: centre, radius: radius, startAngle: .radians(angle - sweep), endAngle: .radians(angle), clockwise: false)
        let gradient = Gradient(stops: [
            .init(color: AppColors.accent.withValues(alpha: 0), location: 0),
            .init(color: AppColors.accent.withValues(alpha: 0.9), location: sweep / (2 * Double.pi)),
        ])
        canvas.stroke(
            trail,
            with: .conicGradient(gradient, center: centre, angle: .radians(angle - sweep)),
            style: StrokeStyle(lineWidth: 3, lineCap: .round)
        )
    }
}

/// The photo banner that opens the Visa, Tour and Hotel screens — the port of
/// lib/core/presentation/widgets/photo_hero.dart: a photo with rounded bottom
/// corners, a scrim darkening towards the headline, a left-aligned title and
/// subtitle, and a frosted back button.
struct PhotoHero<Photo: View>: View {
    @ViewBuilder var image: () -> Photo
    let title: String
    let subtitle: String
    var contentMaxWidth: CGFloat = .infinity

    @Environment(AppRouter.self) var router

    var body: some View {
        GeometryReader { proxy in
            let topPad = proxy.safeAreaInsets.top
            ZStack(alignment: .bottom) {
                image()
                    .frame(width: proxy.size.width, height: proxy.size.height + topPad)
                    .clipped()
                LinearGradient(
                    stops: [
                        .init(color: Colors.black.withValues(alpha: 0.30), location: 0),
                        .init(color: Colors.transparent, location: 0.42),
                        .init(color: Colors.black.withValues(alpha: 0.72), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).textStyle(AppTypography.heading(32, color: Colors.white, height: 1.1))
                    VGap(8)
                    Text(subtitle).textStyle(AppTypography.body(13, color: Colors.white.withValues(alpha: 0.92), height: 1.4))
                }
                .frame(maxWidth: contentMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.screenH, topPad + 66, AppSpacing.screenH, 26)
            }
            .overlay(alignment: .topLeading) {
                GlassBackButton { Task { await router.maybePop() } }
                    .padding(.top, topPad + 8)
                    .padding(.leading, AppSpacing.md)
            }
            .clipShape(UnevenRoundedRectangle(cornerRadii: BorderRadius.vertical(bottom: 28)))
            .ignoresSafeArea(edges: .top)
        }
        // A minimum, not a fixed height: a large text size grows the photo
        // instead of running the headline under the back button.
        .frame(minHeight: 310)
    }
}

/// Frosted-glass circular back button, used over the hero photo.
struct GlassBackButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Icon(Icons.arrow_back_rounded, size: 22, color: Colors.white)
                .frame(width: 42, height: 42)
                .background(.ultraThinMaterial, in: Circle())
                .background(Circle().fill(Colors.white.withValues(alpha: 0.22)))
                .overlay(Circle().stroke(Colors.white.withValues(alpha: 0.45), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Corner ribbon naming the flavor in non-production debug builds — Flutter's
/// `Banner(location: BannerLocation.topStart)`.
struct FlavorBanner: View {
    var body: some View {
        #if DEBUG
        if F.showFlavorBanner {
            GeometryReader { _ in
                Text(F.name)
                    .textStyle(AppTypography.body(12, weight: .w700, color: Colors.white, letterSpacing: 1))
                    .frame(width: 120, height: 18)
                    .background(Colors.green.withValues(alpha: 150.0 / 255.0))
                    .rotationEffect(.degrees(-45))
                    .offset(x: -32, y: 18)
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
        }
        #endif
    }
}
