// Port of lib/features/hotel/presentation/pages/hotel_page.dart
import SwiftUI
import UIKit

/// HOTEL BOOKING — the hotel-categories landing page.
///
/// Opened when the user taps the "Hotel" service tile on the home screen.
/// Mirrors the Tour screen's structure — a photo hero, then a two-column grid
/// of category cards, then the departments contact block. Tapping a card
/// opens that category's `HotelDetailPage`.
struct HotelPage: View {
    @Environment(AppContainer.self) private var container

    init() {}

    var body: some View {
        let hotels = container.hotelList.state

        Scaffold(backgroundColor: AppColors.surface) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 1. Photo hero — brand promise for the hotel service.
                    HotelHero()
                    VGap(AppSpacing.xl)

                    // 2. Section heading.
                    VStack(spacing: 0) {
                        Text(LocaleKeys.hotel_find_perfect_stay.tr())
                            .multilineTextAlignment(.center)
                            .textStyle(AppTypography.heading(19))
                        VGap(4)
                        Text(LocaleKeys.hotel_from_business_trips_to_luxury_escapes.tr())
                            .multilineTextAlignment(.center)
                            .textStyle(AppTypography.body(13, color: AppColors.textSecondary))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, AppSpacing.screenH)
                    VGap(AppSpacing.lg)

                    // 3. Two-column grid of live hotel cards.
                    catalogue(hotels)
                        .padding(.horizontal, AppSpacing.screenH)
                    VGap(AppSpacing.xl)

                    // 4. Talk to the right team — Ticket Department contact card.
                    DepartmentsSection(
                        title: LocaleKeys.hotel_need_help_with_booking.tr(),
                        subtitle: "Our ticketing specialists can help you lock in the right "
                            + "room and rate — reach out anytime.",
                        include: [.ticket]
                    )
                    .padding(.horizontal, AppSpacing.screenH)
                    VGap(AppSpacing.section)
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func catalogue(_ hotels: AsyncValue<[HotelModel]>) -> some View {
        hotels.when(
            data: { items -> AnyView in
                items.isEmpty
                    ? AnyView(HotelCatalogueMessage(
                        icon: Icons.hotel_outlined,
                        message: "No hotels are available right now."
                    ))
                    : AnyView(hotelGrid(items))
            },
            error: { _ -> AnyView in
                AnyView(HotelCatalogueMessage(
                    icon: Icons.cloud_off_rounded,
                    message: "Unable to load hotels. Please try again.",
                    onRetry: { container.hotelList.invalidate() }
                ))
            },
            loading: { () -> AnyView in
                AnyView(
                    ProgressView()
                        .tint(AppColors.primary)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xl)
                )
            }
        )
    }

    /// `LayoutBuilder` + `Wrap(spacing: 14, runSpacing: 14)` of cards that are
    /// each `(maxWidth - spacing) / 2` wide — exactly two per run.
    private func hotelGrid(_ items: [HotelModel]) -> some View {
        let spacing: CGFloat = 14
        let rows: [[Int]] = stride(from: 0, to: items.count, by: 2).map { start in
            Array(start..<min(start + 2, items.count))
        }
        return VStack(alignment: .leading, spacing: spacing) {
            ForEach(rows, id: \.self) { row in
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(row, id: \.self) { i in
                        Reveal(index: i) {
                            HotelCard(hotel: items[i])
                        }
                        .frame(maxWidth: .infinity)
                    }
                    if row.count < 2 {
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                    }
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------
private struct HotelHero: View {
    var body: some View {
        PhotoHero(
            image: {
                NetworkImage(
                    "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=1200",
                    fit: .cover
                ) {
                    AppColors.primarySurface
                } error: {
                    AppColors.primarySurface
                }
            },
            title: LocaleKeys.hotel_stays_for_every_kind_of_trip.tr(),
            subtitle: LocaleKeys.hotel_handpicked_hotels_resorts_and_guesthouses_booked.tr()
        )
    }
}

// ---------------------------------------------------------------------------
// Hotel card
// ---------------------------------------------------------------------------

/// One active-hotel card sourced from `ListActiveHotels`.
private struct HotelCard: View {
    let hotel: HotelModel

    var body: some View {
        Button {
            Task {
                let _: Void? = await showModalBottomSheet(backgroundColor: Colors.transparent) { _ in
                    HotelDetailsSheet(hotel: hotel)
                }
            }
        } label: {
            card
        }
        .buttonStyle(HotelCardPressStyle())
    }

    private var subtitle: String {
        if let summary = hotel.summary, !summary.isEmpty { return summary }
        return hotel.location
    }

    private var card: some View {
        Color.clear
            .aspectRatio(0.92, contentMode: .fit)
            .overlay {
                FillNetworkImage(url: hotel.imageUrl) {
                    AppColors.primarySurface
                } error: {
                    AppColors.primarySurface
                        .overlay { Icon(Icons.hotel_rounded, color: AppColors.textTertiary) }
                }
            }
            .overlay {
                // Bottom scrim for legibility.
                LinearGradient(
                    stops: [
                        .init(color: Colors.black.withValues(alpha: 0.15), location: 0.0),
                        .init(color: Colors.black.withValues(alpha: 0.35), location: 0.45),
                        .init(color: Colors.black.withValues(alpha: 0.85), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .topTrailing) {
                // Frosted rating badge, top-right.
                ratingBadge
                    .padding(.top, 10)
                    .padding(.trailing, 10)
            }
            .overlay(alignment: .bottomLeading) {
                // Title + description.
                VStack(alignment: .leading, spacing: 0) {
                    Text(hotel.name)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .textStyle(AppTypography.heading(14.5, color: Colors.white, height: 1.15))
                    VGap(3)
                    Text(subtitle)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .textStyle(AppTypography.body(
                            10.5,
                            color: Colors.white.withValues(alpha: 0.85),
                            height: 1.25
                        ))
                }
                .padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .contentShape(RoundedRectangle(cornerRadius: 20))
    }

    private var ratingBadge: some View {
        HStack(spacing: 0) {
            Icon(Icons.star_rounded, size: 15, color: Colors.amber)
            HGap(2)
            Text(hotelAsFixed0(hotel.rating))
                .textStyle(AppTypography.body(11, weight: .w700, color: Colors.white))
        }
        .frame(width: 34, height: 34)
        .background(RoundedRectangle(cornerRadius: 12).fill(Colors.white.withValues(alpha: 0.20)))
        // BackdropFilter(ImageFilter.blur(sigmaX: 8, sigmaY: 8)).
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Colors.white.withValues(alpha: 0.40), lineWidth: 1)
                .padding(0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// `_HotelCardState._pressed`: GestureDetector's onTapDown / onTapUp /
/// onTapCancel flipping an `AnimatedScale` (0.97, 140 ms, easeOut).
private struct HotelCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct HotelCatalogueMessage: View {
    let icon: IconData
    let message: String
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Icon(icon, size: 42, color: AppColors.textTertiary)
            VGap(10)
            Text(message)
                .multilineTextAlignment(.center)
                .textStyle(AppTypography.body(13, color: AppColors.textSecondary))
            if let onRetry {
                VGap(10)
                Button("Retry", action: onRetry)
                    .buttonStyle(TextButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
    }
}

/// Read-only details for a live hotel from the active hotel catalogue.
///
/// Shared by the full hotel catalogue and the Popular Hotels carousel on the
/// home screen so both entry points show the same hotel data.
struct HotelDetailsSheet: View {
    let hotel: HotelModel

    init(hotel: HotelModel) {
        self.hotel = hotel
    }

    var body: some View {
        // `SingleChildScrollView` inside a height-capped container: as tall as
        // the content, scrolling only once it no longer fits.
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
                .scrollIndicators(.hidden)
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.78)
        .background(
            UnevenRoundedRectangle(cornerRadii: BorderRadius.vertical(top: 28))
                .fill(AppColors.surface)
                // The Flutter sheet runs to the bottom edge of the screen.
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(AppColors.border)
                .frame(width: 42, height: 4)
                .frame(maxWidth: .infinity)
            VGap(18)
            Text(hotel.name).textStyle(AppTypography.heading(21))
            VGap(4)
            Text(hotel.location)
                .textStyle(AppTypography.body(13, color: AppColors.textSecondary))
            if let summary = hotel.summary, !summary.isEmpty {
                VGap(16)
                Text(summary)
                    .textStyle(AppTypography.body(13, color: AppColors.textSecondary, height: 1.4))
            }
            if !hotel.amenities.isEmpty {
                VGap(20)
                Text("Amenities").textStyle(AppTypography.heading(16))
                VGap(10)
                HotelWrapLayout(spacing: 8, runSpacing: 8) {
                    ForEach(Array(hotel.amenities.enumerated()), id: \.offset) { _, amenity in
                        AmenityChip(label: amenity)
                    }
                }
            }
            VGap(20)
            Text(verbatim: "From \(hotel.pricePerNight) \(hotel.currency) per night")
                .textStyle(AppTypography.body(15, weight: .w700, color: AppColors.primary))
        }
        .padding(20, 12, 20, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Material 3 `Chip(label: Text(amenity))` under the app's chip theme:
/// white, hairline border, 13 w500 label, fully rounded, one line.
private struct AmenityChip: View {
    let label: String

    var body: some View {
        Text(label)
            .lineLimit(1)
            .textStyle(AppTypography.body(13, weight: .w500))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minHeight: 32)
            .background(Capsule().fill(AppColors.surface))
            .overlay(Capsule().stroke(AppColors.border, lineWidth: 1).padding(0.5))
            // MaterialTapTargetSize.padded: each chip occupies a 48pt-tall slot.
            .frame(minHeight: 48)
    }
}

/// Automatic entrance animation — fades, slides up, and scales its `content`
/// in. `index` × `stagger` delays the start so the list reveals one-by-one.
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
            .scaleEffect(0.94 + 0.06 * t)
            .visualEffect { view, proxy in
                // SlideTransition(begin: Offset(0, 0.16)) — a fraction of the
                // child's own height.
                view.offset(y: (1 - t) * 0.16 * proxy.size.height)
            }
            .opacity(t)
            .task {
                try? await Task.sleep(for: Self.stagger * index)
                guard !Task.isCancelled else { return }
                // 480 ms, Curves.easeOutCubic.
                withAnimation(.timingCurve(0.215, 0.61, 0.355, 1, duration: 0.48)) {
                    progress = 1
                }
            }
    }
}

/// `CachedNetworkImage(fit: BoxFit.cover)` inside a `Stack(fit: StackFit.expand)`:
/// the photo takes exactly the space it is given and is cropped to it.
private struct FillNetworkImage<Placeholder: View, ErrorView: View>: View {
    let url: String
    let placeholder: () -> Placeholder
    let errorView: () -> ErrorView

    init(
        url: String,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder error: @escaping () -> ErrorView
    ) {
        self.url = url
        self.placeholder = placeholder
        self.errorView = error
    }

    var body: some View {
        GeometryReader { proxy in
            NetworkImage(
                url,
                width: proxy.size.width,
                height: proxy.size.height,
                fit: .cover,
                placeholder: placeholder,
                error: errorView
            )
        }
    }
}

/// Dart's `double.toStringAsFixed(0)` (halves round away from zero).
private func hotelAsFixed0(_ value: Double) -> String {
    guard value.isFinite else { return value.isNaN ? "NaN" : (value < 0 ? "-Infinity" : "Infinity") }
    return String(format: "%.0f", value.rounded(.toNearestOrAwayFromZero))
}

/// Flutter's `Wrap(spacing:, runSpacing:)`: children laid out left to right,
/// a new run starting whenever the next child no longer fits; runs and
/// children are start-aligned. Used by the hotel pages (`HotelDetailsSheet`
/// amenities, `HotelDetailPage`'s "Ideal for" chips).
struct HotelWrapLayout: Layout {
    var spacing: CGFloat = 0
    var runSpacing: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = runs(maxWidth: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + runSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = runs(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for (index, size) in zip(row.indices, row.sizes) {
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + runSpacing
        }
    }

    private struct Run {
        var indices: [Int] = []
        var sizes: [CGSize] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func runs(maxWidth: CGFloat, subviews: Subviews) -> [Run] {
        var result: [Run] = []
        var current = Run()
        let childProposal = ProposedViewSize(width: maxWidth.isFinite ? maxWidth : nil, height: nil)
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(childProposal)
            // Flutter's `precisionErrorTolerance` keeps exact fits on one run.
            if !current.indices.isEmpty && current.width + spacing + size.width > maxWidth + 1e-10 {
                result.append(current)
                current = Run()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
            current.sizes.append(size)
        }
        if !current.indices.isEmpty { result.append(current) }
        return result
    }
}
