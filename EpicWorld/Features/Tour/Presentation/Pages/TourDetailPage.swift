// Port of lib/features/tour/presentation/pages/tour_detail_page.dart

import SwiftUI

/// TOUR DETAIL — the full description for a single `TourPackage`.
///
/// Layout: a collapsing parallax hero (`SliverAppBar`) that shrinks into a
/// compact title bar as you scroll, then the content sections below (starting
/// with a price + quick-facts summary card). Presentational only — no live
/// booking.
struct TourDetailPage: View {
    let tour: TourPackage

    init(tour: TourPackage) {
        self.tour = tour
    }

    var body: some View {
        Scaffold(backgroundColor: AppColors.surface) {
            GeometryReader { outer in
                let topPad = outer.safeAreaInsets.top
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // 1. Collapsing parallax hero.
                        CollapsingHero(tour: tour, topPad: topPad)
                            .zIndex(1)

                        // 2. Content.
                        content
                    }
                }
                .scrollIndicators(.hidden)
                .coordinateSpace(.named(CollapsingHero.scrollSpace))
                .ignoresSafeArea(edges: .top)
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            VGap(AppSpacing.xl)

            // Summary card — price + quick facts, above the overview.
            Reveal(index: 0) {
                TourSummaryCard(tour: tour)
                    .padding(.horizontal, AppSpacing.screenH)
            }
            VGap(AppSpacing.xl)

            // Overview.
            Reveal(index: 1) {
                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader(
                        icon: Icons.travel_explore_rounded,
                        title: LocaleKeys.common_overview.tr(),
                        color: AppColors.info
                    )
                    VGap(AppSpacing.md)
                    OverviewCard(text: tour.overview)
                }
            }
            .padding(.horizontal, AppSpacing.screenH)
            VGap(AppSpacing.xl)

            // Highlights.
            VStack(alignment: .leading, spacing: 0) {
                Reveal(index: 2) {
                    SectionHeader(
                        icon: Icons.auto_awesome_rounded,
                        title: LocaleKeys.tour_tour_highlights.tr(),
                        color: AppColors.rose
                    )
                }
                VGap(AppSpacing.md)
                Highlights(items: tour.highlights)
            }
            .padding(.horizontal, AppSpacing.screenH)
            VGap(AppSpacing.xl)

            // Sightseeing (full-bleed strip).
            Reveal(index: 3) {
                SectionHeader(
                    icon: Icons.photo_camera_rounded,
                    title: LocaleKeys.tour_sightseeing.tr(),
                    color: AppColors.violet
                )
                .padding(.horizontal, AppSpacing.screenH)
            }
            VGap(AppSpacing.md)
            SightseeingStrip(spots: tour.sightseeing)
            VGap(AppSpacing.xl)

            // Itinerary.
            VStack(alignment: .leading, spacing: 0) {
                Reveal(index: 4) {
                    SectionHeader(
                        icon: Icons.map_rounded,
                        title: LocaleKeys.tour_day_by_day_itinerary.tr(),
                        color: AppColors.teal
                    )
                }
                VGap(AppSpacing.lg)
                Itinerary(days: tour.itinerary)
            }
            .padding(.horizontal, AppSpacing.screenH)
            VGap(AppSpacing.xl)

            // Included / not included.
            VStack(spacing: 0) {
                Reveal(index: 5) {
                    IncludedCard(included: true, items: tour.included)
                }
                VGap(AppSpacing.md)
                Reveal(index: 6) {
                    IncludedCard(included: false, items: tour.notIncluded)
                }
            }
            .padding(.horizontal, AppSpacing.screenH)
            // Breathing room at the end of the page.
            VGap(AppSpacing.section)
        }
    }
}

// ---------------------------------------------------------------------------
// Collapsing hero
// ---------------------------------------------------------------------------

/// A `SliverAppBar` whose photo hero parallaxes and collapses into a compact
/// title bar as the page scrolls. The big title/route/flag fade out while a
/// small pinned title fades in.
///
/// Drawn as the scroll view's first child and kept pinned to the top: its
/// height is the sliver's current extent (`topPad + 310` expanded, stretching
/// on overscroll, down to `topPad + kToolbarHeight` collapsed).
private struct CollapsingHero: View {
    static let scrollSpace = "tourDetailScroll"

    /// Matches the visa screen hero height for a consistent banner across pages.
    static let expanded: CGFloat = 310

    let tour: TourPackage
    let topPad: CGFloat

    @Environment(AppRouter.self) var router

    var body: some View {
        let maxExtent = topPad + Self.expanded
        let minExtent = topPad + AppTheme.toolbarHeight

        GeometryReader { proxy in
            let scrollY = proxy.frame(in: .named(Self.scrollSpace)).minY
            let current = max(minExtent, maxExtent + scrollY)
            // 0 when fully expanded, 1 when fully collapsed.
            let t = min(max((maxExtent - current) / (maxExtent - minExtent), 0), 1)

            hero(t: t)
                .frame(width: proxy.size.width, height: current)
                .clipped()
                .offset(y: -scrollY)
        }
        .frame(height: maxExtent)
    }

    private func hero(t: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // SliverAppBar(backgroundColor: AppColors.primary).
            AppColors.primary

            // Static banner photo (no motion).
            Color.clear
                .overlay {
                    NetworkImage(tour.imageUrl, fit: .cover) {
                        AppColors.primarySurface
                    } error: {
                        AppColors.primarySurface
                    }
                }
                .clipped()
            LinearGradient(
                stops: [
                    .init(color: Colors.black.withValues(alpha: 0.30 + 0.35 * t), location: 0.0),
                    .init(color: Colors.black.withValues(alpha: 0.18), location: 0.4),
                    .init(color: Colors.black.withValues(alpha: 0.82), location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Expanded hero content — fades out as it collapses. The title
            // now sits where the duration badge used to be; the flag moves
            // down beside the location line.
            VStack(alignment: .leading, spacing: 0) {
                Text(tour.title)
                    .textStyle(AppTypography.heading(27, color: Colors.white, height: 1.1))
                VGap(8)
                Text(tour.route)
                    .textStyle(AppTypography.body(13.5, weight: .w600, color: AppColors.accent, height: 1.3))
                VGap(10)
                HStack(spacing: 0) {
                    FlagDot(code: tour.countryCode, size: 22)
                    HGap(8)
                    Text(tour.country)
                        .textStyle(AppTypography.body(13, weight: .w600, color: Colors.white))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .opacity(min(max(1 - t * 1.4, 0), 1))
            .padding(.horizontal, AppSpacing.screenH)
            .padding(.bottom, 34)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            // Collapsed title — fades in as it collapses.
            Text(tour.title)
                .textStyle(AppTypography.heading(16, color: Colors.white))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: AppTheme.toolbarHeight)
                .padding(.leading, 62)
                .padding(.trailing, AppSpacing.screenH)
                .opacity(t)
                .padding(.top, topPad)

            // Glass back button (always visible).
            GlassIconButton(icon: Icons.arrow_back_rounded) {
                Task { await router.maybePop() }
            }
            .padding(.top, topPad + 6)
            .padding(.leading, AppSpacing.md)
        }
    }
}

/// Frosted-glass circular icon button used over the hero photo.
private struct GlassIconButton: View {
    let icon: IconData
    let onTap: () -> Void

    var body: some View {
        Icon(icon, size: 21, color: Colors.white)
            .frame(width: 40, height: 40)
            .background(Circle().fill(Colors.black.withValues(alpha: 0.28)))
            // BackdropFilter(ImageFilter.blur(sigmaX: 8, sigmaY: 8)).
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().strokeBorder(Colors.white.withValues(alpha: 0.35), lineWidth: 1))
            .clipShape(Circle())
            .contentShape(Circle())
            .onTapGesture(perform: onTap)
    }
}

/// Small circular country flag over the hero.
private struct FlagDot: View {
    let code: String
    var size: CGFloat = 34

    var body: some View {
        // The 2pt white ring insets the photo, as Container does for a border.
        NetworkImage("https://flagcdn.com/w160/\(code).png", width: size - 4, height: size - 4, fit: .cover) {
            AppColors.primarySurface
        } error: {
            AppColors.primarySurface
        }
        .clipShape(Circle())
        .padding(2)
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(Colors.white, lineWidth: 2))
    }
}

// ---------------------------------------------------------------------------
// Summary card
// ---------------------------------------------------------------------------

/// Price + quick-facts card shown just above the overview, styled as an
/// actual ticket stub — a torn-notch seam separates the price from the trip
/// facts, reusing the same `TicketCardShell` the app's flight/boarding-pass
/// screens are built on. Information only — no buttons.
private struct TourSummaryCard: View {
    let tour: TourPackage

    var body: some View {
        TicketCardShell(
            top: {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        Icon(Icons.card_travel_rounded, size: 17, color: Colors.white)
                            .frame(width: 32, height: 32)
                            .boxDecoration(gradient: AppColors.heroGradient, radius: 10)
                        HGap(10)
                        Text(LocaleKeys.tour_starting_from.tr())
                            .textStyle(AppTypography.body(12.5, color: AppColors.textSecondary))
                        Spacer(minLength: 0)
                        // "per person" pill.
                        Text(LocaleKeys.tour_per_person.tr())
                            .textStyle(AppTypography.body(10.5, weight: .w700, color: AppColors.primary))
                            .padding(horizontal: 10, vertical: 4)
                            .boxDecoration(color: AppColors.primary.withValues(alpha: 0.10), radius: 30)
                    }
                    VGap(10)
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(Formatters.grouped(tour.priceFrom))
                            .textStyle(AppTypography.heading(34, color: AppColors.primary))
                        Text(tour.currency)
                            .textStyle(AppTypography.body(13, weight: .w700, color: AppColors.textPrimary))
                            .padding(.leading, 6)
                    }
                }
            },
            // Quick facts as an at-a-glance stat row below the perforated seam.
            bottom: {
                HStack(spacing: 0) {
                    TicketStat(
                        icon: Icons.access_time_rounded,
                        color: AppColors.info,
                        text: tour.duration
                    )
                    .frame(maxWidth: .infinity)
                    Rectangle().fill(AppColors.divider).frame(width: 1, height: 38)
                    TicketStat(
                        icon: Icons.location_on_rounded,
                        color: AppColors.error,
                        text: tour.country
                    )
                    .frame(maxWidth: .infinity)
                    Rectangle().fill(AppColors.divider).frame(width: 1, height: 38)
                    TicketStat(
                        icon: Icons.groups_rounded,
                        color: AppColors.accent,
                        text: "Group & private"
                    )
                    .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: .infinity)
            },
            bottomHeight: 68,
            margin: EdgeInsets()
        )
    }
}

/// One quick-fact in `TourSummaryCard`'s stat row: a small coloured icon
/// over a centred label.
private struct TicketStat: View {
    let icon: IconData
    let color: Color
    let text: String

    var body: some View {
        VStack(spacing: 0) {
            Icon(icon, size: 16, color: color)
            VGap(4)
            Text(text)
                .textStyle(AppTypography.body(10.5, weight: .w700, color: AppColors.textPrimary, height: 1.15))
                .lineLimit(2)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
        }
    }
}

// ---------------------------------------------------------------------------
// Overview
// ---------------------------------------------------------------------------

/// Overview text inside a soft card with a leading gradient accent bar.
private struct OverviewCard: View {
    let text: String

    var body: some View {
        // IntrinsicHeight + CrossAxisAlignment.stretch: the bar spans the text.
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 4)
                .fill(AppColors.primaryGradient)
                .frame(width: 4)
            HGap(14)
            Text(text)
                .textStyle(AppTypography.body(13.5, color: AppColors.textSecondary, height: 1.6))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .boxDecoration(
            color: AppColors.surface,
            radius: 18,
            borderColor: AppColors.border,
            shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: Offset(0, 8))]
        )
    }
}

// ---------------------------------------------------------------------------
// Highlights
// ---------------------------------------------------------------------------
private struct Highlights: View {
    let items: [String]

    /// `LayoutBuilder`'s `constraints.maxWidth`.
    @State var width: CGFloat = 0

    var body: some View {
        let spacing: CGFloat = 12
        let cardWidth = max(0, (width - spacing) / 2)

        VStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(stride(from: 0, to: items.count, by: 2)), id: \.self) { start in
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(start..<min(start + 2, items.count), id: \.self) { i in
                        Reveal(index: i + 3) {
                            HStack(alignment: .top, spacing: 0) {
                                // Simple flat check in the secondary (accent) colour.
                                Icon(Icons.check_circle_rounded, size: 19, color: AppColors.accent)
                                    .padding(.top, 1)
                                HGap(10)
                                Text(items[i])
                                    .textStyle(AppTypography.body(12.5, weight: .w600, color: AppColors.textPrimary, height: 1.3))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(horizontal: 14, vertical: 13)
                            .frame(width: cardWidth)
                            .boxDecoration(color: AppColors.surface, radius: 14, borderColor: AppColors.border)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .readWidth($width)
    }
}

// ---------------------------------------------------------------------------
// Sightseeing
// ---------------------------------------------------------------------------
private struct SightseeingStrip: View {
    let spots: [TourSpot]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                ForEach(Array(spots.enumerated()), id: \.offset) { i, spot in
                    Reveal(index: i + 4) {
                        SightseeingCard(spot: spot, index: i + 1)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenH)
        }
        // clipBehavior: Clip.none — the card shadows spill past the strip.
        .scrollClipDisabled()
        .frame(height: 218)
    }
}

/// Sightseeing slide: a white "framed photo" card — the image sits in a rounded
/// white mount with a numbered badge over it and the place name on a caption
/// strip beneath, so it reads like a polished postcard in the carousel.
private struct SightseeingCard: View {
    let spot: TourSpot
    let index: Int

    /// Dart `index.toString().padLeft(2, '0')`.
    private var badge: String {
        let digits = String(index)
        return String(repeating: "0", count: max(0, 2 - digits.count)) + digits
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                Color.clear
                    .overlay {
                        NetworkImage(spot.imageUrl, fit: .cover) {
                            AppColors.primarySurface
                        } error: {
                            ZStack {
                                AppColors.primarySurface
                                Icon(Icons.image_outlined, color: AppColors.textTertiary)
                            }
                        }
                    }
                    .clipped()
                // Soft top-to-bottom shade so the badge stays legible.
                LinearGradient(
                    stops: [
                        .init(color: Colors.black.withValues(alpha: 0.28), location: 0.0),
                        .init(color: Colors.transparent, location: 0.55),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                // Numbered badge — the stop's position in the tour.
                Text(badge)
                    .textStyle(AppTypography.body(11, weight: .w800, color: Colors.white))
                    .padding(horizontal: 9, vertical: 4)
                    .boxDecoration(color: AppColors.accent, radius: 30)
                    .padding(.top, 8)
                    .padding(.leading, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            VGap(10)
            HStack(spacing: 0) {
                Icon(Icons.location_on_rounded, size: 15, color: AppColors.primary)
                HGap(4)
                Text(spot.name)
                    .textStyle(AppTypography.heading(13.5))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(4, 0, 4, 4)
        }
        .padding(7)
        .frame(width: 170, height: 218)
        .boxDecoration(
            color: AppColors.surface,
            radius: 22,
            borderColor: AppColors.border,
            shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: Offset(0, 8))]
        )
    }
}

// ---------------------------------------------------------------------------
// Itinerary
// ---------------------------------------------------------------------------
private struct Itinerary: View {
    let days: [TourDay]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { i, day in
                Reveal(index: i + 4) {
                    ItineraryRow(
                        index: i + 1,
                        day: day,
                        isLast: i == days.count - 1
                    )
                }
            }
        }
    }
}

private struct ItineraryRow: View {
    let index: Int
    let day: TourDay
    let isLast: Bool

    var body: some View {
        // IntrinsicHeight: the rail's connector runs the card's full height.
        HStack(alignment: .top, spacing: 0) {
            // Progress rail: a ringed step node with a gradient connector down to
            // the next stop. The final day shows a finish flag instead of a number.
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(AppColors.accent.withValues(alpha: 0.16))
                    ZStack {
                        if isLast {
                            Icon(Icons.flag_rounded, size: 15, color: Colors.white)
                        } else {
                            Text(verbatim: "\(index)")
                                .textStyle(AppTypography.body(13, weight: .w800, color: Colors.white))
                        }
                    }
                    .frame(width: 30, height: 30)
                    .boxDecoration(
                        gradient: LinearGradient(
                            colors: [AppColors.accent, Color.lerp(AppColors.accent, Colors.white, 0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        circle: true,
                        shadows: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 8, offset: Offset(0, 3))]
                    )
                }
                .frame(width: 40, height: 40)
                if !isLast {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppColors.accent.withValues(alpha: 0.55),
                                    AppColors.accent.withValues(alpha: 0.12),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 3)
                        .padding(.vertical, 4)
                }
            }
            HGap(14)
            VStack(alignment: .leading, spacing: 0) {
                // "DAY X" as a soft pill badge.
                Text(verbatim: isLast ? "FINAL DAY" : "DAY \(index)")
                    .textStyle(AppTypography.body(10, weight: .w800, color: AppColors.primary, letterSpacing: 1.2))
                    .padding(horizontal: 10, vertical: 4)
                    .boxDecoration(color: AppColors.primarySurface, radius: 30)
                VGap(8)
                Text(day.title).textStyle(AppTypography.heading(14.5))
                VGap(5)
                Text(day.description)
                    .textStyle(AppTypography.body(12.5, color: AppColors.textSecondary, height: 1.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .boxDecoration(
                color: AppColors.surface,
                radius: 16,
                borderColor: AppColors.border,
                shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: Offset(0, 5))]
            )
            .padding(.bottom, isLast ? 0 : AppSpacing.md)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// ---------------------------------------------------------------------------
// Included / Not included
// ---------------------------------------------------------------------------
private struct IncludedCard: View {
    let included: Bool
    let items: [String]

    @Environment(\.displayScale) var displayScale

    var body: some View {
        let color = included ? AppColors.success : AppColors.textTertiary
        let itemIcon = included ? Icons.check_rounded : Icons.close_rounded

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                // Tinted rounded-square badge holding the header icon.
                Icon(included ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 20, color: color)
                    .frame(width: 34, height: 34)
                    .boxDecoration(color: color.withValues(alpha: 0.12), radius: 11)
                HGap(11)
                Text(included ? "What's included" : "Not included")
                    .textStyle(AppTypography.heading(16))
                    .frame(maxWidth: .infinity, alignment: .leading)
                // Count pill.
                Text(verbatim: "\(items.count)")
                    .textStyle(AppTypography.body(11.5, weight: .w800, color: color))
                    .padding(horizontal: 10, vertical: 4)
                    .boxDecoration(color: color.withValues(alpha: 0.12), radius: 30)
            }
            VGap(14)
            // Divider(height: 1) with the default zero thickness: one device pixel.
            MaterialDivider(height: 1, thickness: 1 / displayScale, color: AppColors.divider)
            VGap(14)
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                if i > 0 { VGap(12) }
                HStack(alignment: .top, spacing: 0) {
                    // Soft circular badge with a check / cross per item.
                    Icon(itemIcon, size: 13, color: color)
                        .frame(width: 20, height: 20)
                        .boxDecoration(color: color.withValues(alpha: 0.12), circle: true)
                    HGap(11)
                    Text(item)
                        .textStyle(AppTypography.body(
                            13,
                            weight: .w500,
                            color: included ? AppColors.textPrimary : AppColors.textSecondary,
                            height: 1.4
                        ))
                        .padding(.top, 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .boxDecoration(
            color: AppColors.surface,
            radius: 20,
            borderColor: AppColors.border,
            shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: Offset(0, 8))]
        )
    }
}

// ---------------------------------------------------------------------------
// Shared
// ---------------------------------------------------------------------------

/// Modern section heading: a gradient icon tile, the title, and an optional
/// caption underneath. Each section gets its own `color` so the page reads
/// as distinct chapters at a glance instead of one repeated brand-green icon.
private struct SectionHeader: View {
    let icon: IconData
    let title: String
    var color: Color = AppColors.primary

    var body: some View {
        HStack(spacing: 0) {
            Icon(icon, size: 20, color: Colors.white)
                .frame(width: 38, height: 38)
                .boxDecoration(
                    gradient: LinearGradient(
                        colors: [color, Color.lerp(color, Colors.black, 0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    radius: 12,
                    shadows: [BoxShadow(color: color.withValues(alpha: 0.32), blurRadius: 10, offset: Offset(0, 4))]
                )
            HGap(12)
            Text(title)
                .textStyle(AppTypography.heading(19))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Automatic entrance animation — fades + slides up its `child` on mount.
/// `index` × `stagger` delays the start so sections cascade in sequence.
private struct Reveal<Content: View>: View {
    static var stagger: Duration { .milliseconds(85) }

    let index: Int
    let child: Content

    @State private var progress: Double = 0

    init(index: Int = 0, @ViewBuilder child: () -> Content) {
        self.index = index
        self.child = child()
    }

    var body: some View {
        child
            .modifier(RevealSlide(progress: progress, fraction: 0.14))
            .opacity(progress)
            .task {
                try? await Task.sleep(for: Self.stagger * index)
                guard !Task.isCancelled else { return }
                // Curves.easeOutCubic over 500ms.
                withAnimation(.timingCurve(0.215, 0.61, 0.355, 1, duration: 0.5)) {
                    progress = 1
                }
            }
    }
}

/// `SlideTransition(position: Tween(begin: Offset(0, fraction), end: Offset.zero))`:
/// a vertical offset measured in the child's own height.
private struct RevealSlide: GeometryEffect {
    var progress: Double
    let fraction: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(translationX: 0, y: (1 - progress) * fraction * size.height)
        )
    }
}

private extension View {
    /// Reports this view's laid-out width — `LayoutBuilder`'s `maxWidth`.
    func readWidth(_ width: Binding<CGFloat>) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { width.wrappedValue = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, newWidth in width.wrappedValue = newWidth }
            }
        )
    }
}
