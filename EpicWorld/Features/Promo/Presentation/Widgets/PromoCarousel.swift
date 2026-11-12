// Port of lib/features/promo/presentation/widgets/promo_carousel.dart

import SwiftUI

/// Hero section: an auto-playing, card-style carousel of discounted airlines &
/// bus lines.
///
/// Implementation notes (the "how to do card sliders effectively" deliverable):
///  * `enlargeCenterPage` + `viewportFraction: 0.86` lets neighbouring cards
///    peek at the edges — the signature modern "card slider" look.
///  * A separate PageController-free dots indicator (SmoothPageIndicator)
///    is driven from the carousel's `onPageChanged` callback.
///  * Images are loaded with `cached_network_image` so scrolling stays smooth
///    and repeat views are instant.
///  * A dark gradient scrim guarantees white text stays legible over any photo.
///
/// Swift: `carousel_slider` becomes a paging horizontal `ScrollView` (view
/// aligned, 86% wide pages, centred with content margins). Its infinite scroll
/// is the same trick the plugin uses — a very long run of virtual pages read
/// modulo the item count, starting in the middle.
struct PromoCarousel: View {
    let promos: [PromoModel]
    var onTap: ((PromoModel) -> Void)? = nil

    /// carousel_slider's `CarouselOptions` used here.
    private static let height: CGFloat = 168
    private static let viewportFraction: CGFloat = 0.86
    private static let autoPlayInterval = Duration(seconds: 5)
    /// carousel_slider's default `autoPlayAnimationDuration` (800ms) with
    /// `Curves.easeInOutCubic`.
    private static let autoPlayAnimation = Animation.timingCurve(0.645, 0.045, 0.355, 1, duration: 0.8)
    /// Virtual pages per real item (carousel_slider starts at page 10000).
    private static let loopFactor = 2000

    @State private var index = 0
    @State private var position: Int?

    init(promos: [PromoModel], onTap: ((PromoModel) -> Void)? = nil) {
        self.promos = promos
        self.onTap = onTap
        _position = State(initialValue: promos.isEmpty ? nil : promos.count * (Self.loopFactor / 2))
    }

    var body: some View {
        if promos.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 0) {
                carousel
                    .frame(height: Self.height)
                VGap(12)
                // AnimatedSmoothIndicator + ExpandingDotsEffect.
                HStack(spacing: 5) {
                    ForEach(0..<promos.count, id: \.self) { i in
                        Capsule()
                            .fill(i == index ? AppColors.primary : AppColors.border)
                            .frame(width: i == index ? 7 * 3 : 7, height: 7)
                    }
                }
                .animation(.timingCurve(0.215, 0.61, 0.355, 1, duration: 0.3), value: index)
            }
        }
    }

    private var carousel: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let itemWidth = width * Self.viewportFraction
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(0..<(promos.count * Self.loopFactor), id: \.self) { page in
                        PromoCard(promo: promos[page % promos.count], onTap: onTap)
                            .frame(width: itemWidth, height: Self.height)
                            // `enlargeCenterPage` (scale strategy): neighbours
                            // shrink by `easeOut(1 - |offset| · enlargeFactor)`
                            // — the plugin sizes the page to that fraction of
                            // the height and then scales it by the same value.
                            .visualEffect { content, geometry in
                                let offset = (geometry.frame(in: .scrollView).midX - width / 2) / max(itemWidth, 1)
                                let distortion = promoCarouselDistortion(offset)
                                return content.scaleEffect(x: distortion, y: distortion * distortion)
                            }
                            .id(page)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, (width - itemWidth) / 2, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $position)
        }
        .onChange(of: position) { _, page in
            // `onPageChanged: (i, _) => setState(() => _index = i)`.
            guard let page, !promos.isEmpty else { return }
            index = page % promos.count
        }
        // `autoPlay: true` — every interval, slide to the next page. A manual
        // swipe restarts the timer (`pauseAutoPlayOnManualNavigate`).
        .task(id: position) {
            try? await Task.sleep(for: Self.autoPlayInterval)
            guard !Task.isCancelled, let current = position else { return }
            withAnimation(Self.autoPlayAnimation) { position = current + 1 }
        }
    }
}

/// carousel_slider's enlarge distortion for a page `offset` pages away from
/// the centre (`enlargeFactor: 0.18`), eased with `Curves.easeOut`.
private func promoCarouselDistortion(_ offset: CGFloat) -> CGFloat {
    let ratio = min(max(1 - abs(offset) * 0.18, 0), 1)
    return promoCarouselEaseOut(ratio)
}

/// Flutter's `Curves.easeOut` — `Cubic(0.0, 0.0, 0.58, 1.0)`.
private func promoCarouselEaseOut(_ t: CGFloat) -> CGFloat {
    if t <= 0 { return 0 }
    if t >= 1 { return 1 }
    // Solve x(s) = t for the bezier parameter s, then return y(s).
    let x1: CGFloat = 0, x2: CGFloat = 0.58, y1: CGFloat = 0, y2: CGFloat = 1
    func bezier(_ s: CGFloat, _ p1: CGFloat, _ p2: CGFloat) -> CGFloat {
        3 * p1 * s * (1 - s) * (1 - s) + 3 * p2 * s * s * (1 - s) + s * s * s
    }
    var low: CGFloat = 0, high: CGFloat = 1, s = t
    for _ in 0..<24 {
        s = (low + high) / 2
        if bezier(s, x1, x2) < t { low = s } else { high = s }
    }
    return bezier(s, y1, y2)
}

private struct PromoCard: View {
    let promo: PromoModel
    let onTap: ((PromoModel) -> Void)?

    var body: some View {
        let isFlight = promo.type == .flight

        ZStack {
            // Background image with graceful loading / error states.
            NetworkImage(promo.imageUrl, fit: .cover) {
                AppColors.primarySurface
            } error: {
                AppColors.primarySurface
                    .overlay { Icon(Icons.image_outlined, color: AppColors.textTertiary) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            // Scrim for text legibility.
            LinearGradient(
                colors: [Colors.black.withValues(alpha: 0.72), Colors.black.withValues(alpha: 0.15)],
                startPoint: .leading,
                endPoint: .trailing
            )
            VStack(alignment: .leading, spacing: 0) {
                // Discount badge + mode chip.
                HStack(spacing: 0) {
                    BadgeView(text: promo.discountLabel, color: AppColors.accent)
                    HGap(8)
                    BadgeView(
                        text: isFlight ? "Flight" : "Bus",
                        color: Colors.white.withValues(alpha: 0.22),
                        icon: isFlight ? Icons.flight_takeoff : Icons.directions_bus
                    )
                }
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 0) {
                    Text(promo.title)
                        .textStyle(AppTypography.heading(20, color: Colors.white))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    VGap(2)
                    Text(promo.subtitle)
                        .textStyle(AppTypography.body(12, color: Colors.white.withValues(alpha: 0.88)))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .boxDecoration(
            radius: 20,
            shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 14, offset: Offset(0, 6))]
        )
        .padding(.horizontal, 5)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?(promo)
        }
        .allowsHitTesting(onTap != nil)
    }
}

/// Dart `_Badge` (renamed: `Badge` reads like SwiftUI's badge API).
private struct BadgeView: View {
    let text: String
    let color: Color
    var icon: IconData? = nil

    var body: some View {
        HStack(spacing: 0) {
            if let icon {
                Icon(icon, size: 13, color: Colors.white)
                HGap(4)
            }
            Text(text)
                .textStyle(AppTypography.body(11, weight: .w700, color: Colors.white))
        }
        .padding(horizontal: 10, vertical: 5)
        .boxDecoration(color: color, radius: 30)
    }
}
