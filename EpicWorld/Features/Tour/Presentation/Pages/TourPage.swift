// Port of lib/features/tour/presentation/pages/tour_page.dart

import SwiftUI

/// TOUR PACKAGES — the curated-tours landing page.
///
/// Opened when the user taps the "Tour" service tile on the home screen. Mirrors
/// the visa screen's structure — a photo hero, then the content — but here the
/// body is a two-column grid of tour-package cards. Tapping a card (or its
/// "Detail" button) opens that package's `TourDetailPage`.
struct TourPage: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router

    /// `LayoutBuilder`'s `constraints.maxWidth` for the card grid.
    @State private var gridWidth: CGFloat = 0

    init() {}

    var body: some View {
        let tours = container.tourPackageList.state

        Scaffold(backgroundColor: AppColors.surface) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 1. Photo hero — brand promise for the tour service.
                    TourHero()
                    VGap(AppSpacing.xl)

                    // 2. Section heading.
                    VStack(spacing: 0) {
                        Text(LocaleKeys.tour_tour_packages.tr())
                            .textStyle(AppTypography.heading(19))
                            .multilineTextAlignment(.center)
                        VGap(4)
                        Text(LocaleKeys.tour_handpicked_local_international_tours_planned_down.tr())
                            .textStyle(AppTypography.body(13, color: AppColors.textSecondary))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, AppSpacing.screenH)
                    VGap(AppSpacing.lg)

                    // 3. Two-column grid of tour cards.
                    tours.when(
                        data: { items in
                            items.isEmpty
                                ? AnyView(TourPackagesMessage(
                                    icon: Icons.luggage_outlined,
                                    message: "No tour packages are available right now."
                                ))
                                : AnyView(grid(items))
                        },
                        error: { _ in
                            AnyView(TourPackagesMessage(
                                icon: Icons.cloud_off_rounded,
                                message: "Unable to load tour packages. Please try again.",
                                onRetry: { container.tourPackageList.invalidate() }
                            ))
                        },
                        loading: {
                            AnyView(
                                ProgressView()
                                    .tint(AppColors.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, AppSpacing.xl)
                            )
                        }
                    )
                    .padding(.horizontal, AppSpacing.screenH)
                    VGap(AppSpacing.xl)

                    // 4. Talk to the right team — Tour Department contact card.
                    DepartmentsSection(
                        title: LocaleKeys.tour_plan_next_trip_with_us.tr(),
                        subtitle: "Our tour specialists are ready to help — from custom itineraries to group getaways, we've got you covered.",
                        include: [.tour]
                    )
                    .padding(.horizontal, AppSpacing.screenH)
                    VGap(AppSpacing.section)
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    /// `Wrap(spacing: 14, runSpacing: 14)` of cards sized to half the width.
    private func grid(_ items: [TourPackage]) -> some View {
        let spacing: CGFloat = 14
        let cardWidth = max(0, (gridWidth - spacing) / 2)
        return VStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(stride(from: 0, to: items.count, by: 2)), id: \.self) { start in
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(start..<min(start + 2, items.count), id: \.self) { i in
                        Reveal(index: i) {
                            TourCard(
                                tour: items[i],
                                onTap: { router.push(.tourDetail(tour: items[i])) }
                            )
                            .frame(width: cardWidth)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .readWidth($gridWidth)
    }
}

private struct TourPackagesMessage: View {
    let icon: IconData
    let message: String
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Icon(icon, size: 42, color: AppColors.textTertiary)
            VGap(10)
            Text(message)
                .textStyle(AppTypography.body(13, color: AppColors.textSecondary))
                .multilineTextAlignment(.center)
            if let onRetry {
                VGap(10)
                Button {
                    onRetry()
                } label: {
                    Text("Retry").textStyle(AppTypography.labelLarge.copyWith(color: AppColors.primary))
                }
                .buttonStyle(TextButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
    }
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------
private struct TourHero: View {
    var body: some View {
        PhotoHero(
            image: {
                NetworkImage(
                    "https://images.unsplash.com/photo-1528127269322-539801943592?w=1200",
                    fit: .cover
                ) {
                    AppColors.primarySurface
                } error: {
                    AppColors.primarySurface
                }
            },
            title: LocaleKeys.tour_explore_world_with_us.tr(),
            subtitle: LocaleKeys.tour_tailor_made_tour_packages_from_group.tr()
        )
    }
}

// ---------------------------------------------------------------------------
// Tour card
// ---------------------------------------------------------------------------

/// One tour-package card: a full-bleed photo with the title, duration and a
/// "Detail" button overlaid on a bottom scrim.
private struct TourCard: View {
    let tour: TourPackage
    let onTap: () -> Void

    var body: some View {
        Color.clear
            .aspectRatio(0.82, contentMode: .fit)
            .overlay {
                ZStack(alignment: .bottomLeading) {
                    Color.clear
                        .overlay {
                            NetworkImage(tour.imageUrl, fit: .cover) {
                                AppColors.primarySurface
                            } error: {
                                ZStack {
                                    AppColors.primarySurface
                                    Icon(Icons.image_outlined, color: AppColors.textTertiary)
                                }
                            }
                        }
                        .clipped()
                    // Bottom scrim for text legibility.
                    LinearGradient(
                        stops: [
                            .init(color: Colors.transparent, location: 0.35),
                            .init(color: Colors.black.withValues(alpha: 0.25), location: 0.6),
                            .init(color: Colors.black.withValues(alpha: 0.82), location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    VStack(alignment: .leading, spacing: 0) {
                        Text(tour.title)
                            .textStyle(AppTypography.heading(15, color: Colors.white, height: 1.2))
                            .lineLimit(2)
                            .truncationMode(.tail)
                        VGap(6)
                        HStack(spacing: 0) {
                            Icon(Icons.access_time_rounded, size: 13, color: AppColors.accent)
                            HGap(5)
                            Text(tour.duration)
                                .textStyle(AppTypography.body(12, weight: .w600, color: AppColors.accent))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        VGap(10)
                        DetailButton(onTap: onTap)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .contentShape(RoundedRectangle(cornerRadius: 20))
            .onTapGesture(perform: onTap)
    }
}

/// The frosted "Detail →" pill at the bottom of a tour card.
private struct DetailButton: View {
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text(LocaleKeys.tour_detail.tr())
                .textStyle(AppTypography.body(12.5, weight: .w700, color: Colors.white))
            HGap(5)
            Icon(Icons.arrow_forward_rounded, size: 15, color: Colors.white)
        }
        .padding(horizontal: 14, vertical: 9)
        .background(Capsule().fill(Colors.white.withValues(alpha: 0.20)))
        // BackdropFilter(ImageFilter.blur(sigmaX: 6, sigmaY: 6)).
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Colors.white.withValues(alpha: 0.40), lineWidth: 1))
        .clipShape(Capsule())
        .contentShape(Capsule())
        .onTapGesture(perform: onTap)
    }
}

/// Automatic entrance animation — fades, slides up, and scales its `child` in.
/// `index` × `stagger` delays the start so the grid reveals one-by-one.
private struct Reveal<Content: View>: View {
    static var stagger: Duration { .milliseconds(80) }

    let index: Int
    let child: Content

    @State private var progress: Double = 0

    init(index: Int = 0, @ViewBuilder child: () -> Content) {
        self.index = index
        self.child = child()
    }

    var body: some View {
        child
            .scaleEffect(0.94 + 0.06 * progress)
            .modifier(RevealSlide(progress: progress, fraction: 0.16))
            .opacity(progress)
            .task {
                try? await Task.sleep(for: Self.stagger * index)
                guard !Task.isCancelled else { return }
                // Curves.easeOutCubic over 480ms.
                withAnimation(.timingCurve(0.215, 0.61, 0.355, 1, duration: 0.48)) {
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
