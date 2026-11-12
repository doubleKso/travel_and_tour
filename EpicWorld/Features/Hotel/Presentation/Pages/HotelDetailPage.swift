// Port of lib/features/hotel/presentation/pages/hotel_detail_page.dart
import SwiftUI

/// HOTEL DETAIL — the full description for a single `HotelCategory`.
///
/// Opened from the Hotel screen. Presentational only (no live booking form): a
/// photo hero with the title and tagline, a starting-from price card, the
/// overview, an amenities grid, the key features, who it's ideal for, and a
/// photo gallery.
struct HotelDetailPage: View {
    let category: HotelCategory

    init(category: HotelCategory) {
        self.category = category
    }

    var body: some View {
        Scaffold(backgroundColor: AppColors.surface) {
            // Flutter's body runs under the status bar (no AppBar, no SafeArea);
            // the hero reads the top inset itself.
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // 1. Photo hero — icon badge, title, tagline.
                        DetailHero(category: category, topPad: proxy.safeAreaInsets.top)
                        VGap(AppSpacing.xl)

                        VStack(alignment: .leading, spacing: 0) {
                            // Overview.
                            Reveal(index: 1) {
                                VStack(alignment: .leading, spacing: 0) {
                                    SectionHeader(
                                        icon: Icons.info_outline_rounded,
                                        title: LocaleKeys.common_overview.tr(),
                                        color: AppColors.info
                                    )
                                    VGap(AppSpacing.md)
                                    OverviewCard(text: category.overview)
                                }
                            }
                            VGap(AppSpacing.xl)

                            // 4. Amenities.
                            Reveal(index: 2) {
                                SectionHeader(
                                    icon: Icons.room_service_rounded,
                                    title: LocaleKeys.common_amenities.tr(),
                                    caption: "What's on offer",
                                    color: AppColors.violet
                                )
                            }
                            VGap(AppSpacing.md)
                            AmenitiesGrid(amenities: category.amenities)
                            VGap(AppSpacing.xl)

                            // 5. Key features.
                            Reveal(index: 3) {
                                SectionHeader(
                                    icon: Icons.verified_rounded,
                                    title: "What you'll get",
                                    caption: "Every stay includes",
                                    color: AppColors.accent
                                )
                            }
                            VGap(AppSpacing.md)
                            Features(items: category.features)
                            VGap(AppSpacing.xl)

                            // 6. Ideal for.
                            Reveal(index: 4) {
                                SectionHeader(
                                    icon: Icons.favorite_rounded,
                                    title: LocaleKeys.hotel_ideal_for.tr(),
                                    color: AppColors.rose
                                )
                            }
                            VGap(AppSpacing.md)
                            Reveal(index: 4) { IdealFor(items: category.idealFor) }
                            VGap(AppSpacing.xl)
                        }
                        .padding(.horizontal, AppSpacing.screenH)

                        // 7. Gallery — horizontal image strip (full-bleed).
                        Reveal(index: 5) {
                            SectionHeader(
                                icon: Icons.photo_camera_rounded,
                                title: LocaleKeys.hotel_gallery.tr(),
                                caption: "A look inside",
                                color: AppColors.teal
                            )
                            .padding(.horizontal, AppSpacing.screenH)
                        }
                        VGap(AppSpacing.md)
                        GalleryStrip(images: category.gallery)
                        VGap(AppSpacing.section)
                    }
                }
                .scrollIndicators(.hidden)
                .ignoresSafeArea(edges: .top)
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------
private struct DetailHero: View {
    let category: HotelCategory
    /// `MediaQuery.of(context).padding.top`.
    let topPad: CGFloat

    @Environment(AppRouter.self) private var router

    init(category: HotelCategory, topPad: CGFloat) {
        self.category = category
        self.topPad = topPad
    }

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 350)
            .overlay { KenBurnsImage(imageUrl: category.imageUrl) }
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: Colors.black.withValues(alpha: 0.45), location: 0.0),
                        .init(color: Colors.black.withValues(alpha: 0.20), location: 0.4),
                        .init(color: Colors.black.withValues(alpha: 0.80), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .topLeading) {
                // "All hotel categories" back link.
                HStack(spacing: 0) {
                    Icon(Icons.arrow_back_rounded, size: 18, color: Colors.white)
                    HGap(6)
                    Text(LocaleKeys.hotel_all_hotel_categories.tr())
                        .textStyle(AppTypography.body(13, weight: .w600, color: Colors.white))
                }
                .contentShape(Rectangle())
                .onTapGesture { Task { await router.maybePop() } }
                .padding(.top, topPad + 12)
                .padding(.leading, AppSpacing.screenH)
            }
            .overlay(alignment: .bottomLeading) {
                // Title + tagline.
                VStack(alignment: .leading, spacing: 0) {
                    Text(category.title)
                        .textStyle(AppTypography.heading(27, color: Colors.white, height: 1.1))
                    VGap(8)
                    Text(category.tagline)
                        .textStyle(AppTypography.body(
                            13.5,
                            weight: .w600,
                            color: AppColors.accent,
                            height: 1.3
                        ))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.screenH)
                .padding(.bottom, 24)
            }
            .clipShape(UnevenRoundedRectangle(cornerRadii: BorderRadius.vertical(bottom: 28)))
    }
}

// ---------------------------------------------------------------------------
// Amenities grid
// ---------------------------------------------------------------------------
private struct AmenitiesGrid: View {
    let amenities: [HotelAmenity]

    var body: some View {
        // LayoutBuilder + Wrap of tiles `(maxWidth - gap * (columns - 1)) / columns`
        // wide — exactly `columns` per run, top-aligned.
        let columns = 3
        let gap: CGFloat = 12
        let rows: [[Int]] = stride(from: 0, to: amenities.count, by: columns).map { start in
            Array(start..<min(start + columns, amenities.count))
        }
        VStack(alignment: .leading, spacing: gap) {
            ForEach(rows, id: \.self) { row in
                HStack(alignment: .top, spacing: gap) {
                    ForEach(row, id: \.self) { i in
                        Reveal(index: i + 2) {
                            tile(amenities[i])
                        }
                        .frame(maxWidth: .infinity)
                    }
                    ForEach(row.count..<columns, id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                    }
                }
            }
        }
    }

    private func tile(_ amenity: HotelAmenity) -> some View {
        VStack(spacing: 0) {
            AppImage(amenity.asset, width: 21, height: 21, tint: AppColors.primary)
                .frame(width: 42, height: 42)
                .boxDecoration(color: AppColors.primarySurface, radius: 13)
            VGap(8)
            Text(amenity.label)
                .lineLimit(2)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
                .textStyle(AppTypography.body(
                    11.5,
                    weight: .w600,
                    color: AppColors.textPrimary,
                    height: 1.2
                ))
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .padding(1) // the 1pt border insets the Container's child
        .frame(maxWidth: .infinity)
        .boxDecoration(
            color: AppColors.surface,
            radius: 16,
            borderColor: AppColors.border,
            shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: Offset(0, 5))]
        )
    }
}

// ---------------------------------------------------------------------------
// Features
// ---------------------------------------------------------------------------
private struct Features: View {
    let items: [String]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                if i > 0 { VGap(10) }
                Reveal(index: i + 3) {
                    HStack(alignment: .top, spacing: 0) {
                        Icon(Icons.check_rounded, size: 16, color: AppColors.primary)
                            .frame(width: 26, height: 26)
                            .boxDecoration(color: AppColors.primarySurface, radius: 8)
                        HGap(12)
                        Text(item)
                            .textStyle(AppTypography.body(
                                13,
                                weight: .w600,
                                color: AppColors.textPrimary,
                                height: 1.35
                            ))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(14)
                    .padding(1) // border inset
                    .frame(maxWidth: .infinity)
                    .boxDecoration(
                        color: AppColors.surface,
                        radius: 16,
                        borderColor: AppColors.border,
                        shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: Offset(0, 5))]
                    )
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Ideal for
// ---------------------------------------------------------------------------
private struct IdealFor: View {
    let items: [String]

    var body: some View {
        HotelWrapLayout(spacing: 10, runSpacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 0) {
                    Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primary)
                    HGap(7)
                    Text(item)
                        .textStyle(AppTypography.body(12.5, weight: .w600, color: AppColors.primaryDark))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .padding(1) // border inset
                .boxDecoration(
                    color: AppColors.primarySurface,
                    radius: 30,
                    borderColor: AppColors.primary.withValues(alpha: 0.20)
                )
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Gallery
// ---------------------------------------------------------------------------
private struct GalleryStrip: View {
    let images: [String]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 14) {
                ForEach(Array(images.enumerated()), id: \.offset) { i, image in
                    Reveal(index: i + 5) {
                        NetworkImage(image, width: 220, height: 160, fit: .cover) {
                            AppColors.primarySurface
                        } error: {
                            AppColors.primarySurface
                                .overlay { Icon(Icons.image_outlined, color: AppColors.textTertiary) }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenH)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .frame(height: 160)
    }
}

// ---------------------------------------------------------------------------
// Shared
// ---------------------------------------------------------------------------

/// Modern section heading: a gradient icon tile, the title, and an optional
/// caption underneath.
private struct SectionHeader: View {
    let icon: IconData
    let title: String
    var caption: String? = nil
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
            VStack(alignment: .leading, spacing: 0) {
                Text(title).textStyle(AppTypography.heading(19))
                if let caption {
                    VGap(2)
                    Text(caption)
                        .textStyle(AppTypography.body(12, color: AppColors.textPrimary))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Overview text inside a soft card with a leading accent bar.
private struct OverviewCard: View {
    let text: String

    var body: some View {
        // IntrinsicHeight + Row(crossAxisAlignment: stretch): the bar is as
        // tall as the text.
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 4)
                .fill(AppColors.primaryGradient)
                .frame(width: 4)
                .frame(maxHeight: .infinity)
            HGap(14)
            Text(text)
                .textStyle(AppTypography.body(13.5, color: AppColors.textSecondary, height: 1.6))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .padding(1) // border inset
        .frame(maxWidth: .infinity)
        .boxDecoration(
            color: AppColors.surface,
            radius: 18,
            borderColor: AppColors.border,
            shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: Offset(0, 8))]
        )
    }
}

/// Automatic entrance animation — fades + slides up its `content` on mount.
/// `index` × `stagger` delays the start so sections cascade in sequence.
private struct Reveal<Content: View>: View {
    let index: Int
    let content: () -> Content
    static var stagger: Duration { .milliseconds(90) }

    @State private var progress: Double = 0

    init(index: Int = 0, @ViewBuilder content: @escaping () -> Content) {
        self.index = index
        self.content = content
    }

    var body: some View {
        let t = progress
        content()
            .visualEffect { view, proxy in
                // SlideTransition(begin: Offset(0, 0.14)) — a fraction of the
                // child's own height.
                view.offset(y: (1 - t) * 0.14 * proxy.size.height)
            }
            .opacity(t)
            .task {
                try? await Task.sleep(for: Self.stagger * index)
                guard !Task.isCancelled else { return }
                // 500 ms, Curves.easeOutCubic.
                withAnimation(.timingCurve(0.215, 0.61, 0.355, 1, duration: 0.5)) {
                    progress = 1
                }
            }
    }
}

/// Slowly zooming + panning banner image (a "Ken Burns" effect). Loops forever,
/// reversing at each end so the motion is continuous and never jumps.
private struct KenBurnsImage: View {
    let imageUrl: String

    /// `AnimationController(duration: 14 s)..repeat(reverse: true)`.
    @State private var start = Date()

    init(imageUrl: String) {
        self.imageUrl = imageUrl
    }

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { context in
                // Controller value bouncing 0 → 1 → 0, then Curves.easeInOut.
                let cycle = (context.date.timeIntervalSince(start) / 14).truncatingRemainder(dividingBy: 2)
                let linear = cycle <= 1 ? cycle : 2 - cycle
                let t = UnitCurve.easeInOut.value(at: linear)
                NetworkImage(imageUrl, width: proxy.size.width, height: proxy.size.height, fit: .cover) {
                    AppColors.primarySurface
                } error: {
                    AppColors.primarySurface
                }
                .scaleEffect(1.0 + 0.16 * t, anchor: .alignment(0.4 - 0.8 * t, -0.3 + 0.5 * t))
            }
        }
    }
}
