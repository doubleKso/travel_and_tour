// Port of lib/features/home/presentation/pages/home_page.dart

import SwiftUI
import UIKit

@MainActor
private func ignoreHomeRefreshError(_ request: () async throws -> Void) async {
    do {
        try await request()
    } catch {
        // Each provider keeps its own AsyncError while the refresh gesture ends.
    }
}

@MainActor
private func refreshHomeData(_ container: AppContainer) async {
    // Invalidate first so derived locations cannot reuse an old city catalogue.
    container.activeAirportCityList.invalidate()
    container.locationList.invalidate()
    container.hotelList.invalidate()
    container.notificationRemoteList.invalidate()
    // `Future.wait`: the three loads are already running; wait for all of them.
    await ignoreHomeRefreshError { _ = try await container.locationList.future }
    await ignoreHomeRefreshError { _ = try await container.hotelList.future }
    await ignoreHomeRefreshError { _ = try await container.notificationRemoteList.future }
}

@MainActor
private func showRouteRequiredMessage() {
    SnackBarCenter.shared.show("Select both departure and destination to search.", floating: true)
}

/// Flutter's `MediaQuery.of(context).size.height` — the whole screen.
@MainActor
private var homeScreenHeight: CGFloat {
    let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    return scene?.screen.bounds.height ?? 0
}

/// HOME PAGE — reference-matched layout.
///
/// Structure (top → bottom):
///   1. Green gradient header — greeting + notifications
///   2. Service selector       — 5 cards (Air Ticket active, rest "coming soon")
///   3. Air ticket search card — only while Air Ticket is the active service
///   4. Special Deals          — horizontally scrolling promo cards
///   5. Popular Hotels         — horizontally scrolling hotel cards
struct HomePage: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router

    // Only Air Ticket is wired up for now; it stays the active service.
    @State private var activeService: ServiceType = .airTicket

    init() {}

    private func startSearch() {
        let bloc = container.flightBookingBloc
        let booking = bloc.state
        if !booking.hasCompleteRoute {
            showRouteRequiredMessage()
            return
        }
        // Populate the results, then show them beneath the branded loader: the
        // loader is a transparent overlay that blurs the results screen behind it
        // and pops itself when the animation completes, revealing the results.
        bloc.add(.flightSearchRequested)
        router.push(.searchResults)
        router.push(.flightSearchLoading(from: booking.fromLocation, to: booking.toLocation))
    }

    private func onServiceTap(_ service: ServiceType) {
        // Visa opens its own information-only detail page (like Air Ticket's flow).
        if service == .visa {
            router.push(.visa)
            return
        }
        // Tour opens the curated tour-packages page.
        if service == .tour {
            router.push(.tour)
            return
        }
        // Hotel opens the hotel-categories page.
        if service == .hotel {
            router.push(.hotel)
            return
        }
        if !service.enabled {
            SnackBarCenter.shared.show(LocaleKeys.home_is_coming_soon.tr(args: [service.label]), floating: true)
            return
        }
        activeService = service
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 1 + 2. Gradient header containing the greeting and service cards.
                    HeroHeader(
                        activeService: activeService,
                        onServiceTap: onServiceTap,
                        unreadCount: container.unreadNotificationCount,
                        topPad: proxy.safeAreaInsets.top
                    )
                    VGap(AppSpacing.xs)

                    // 3. Active service body (Air Ticket → the search form).
                    Group {
                        if activeService == .airTicket {
                            SearchCardBody(onSearch: startSearch)
                        } else {
                            ComingSoonCard(service: activeService)
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenH)
                    VGap(AppSpacing.xl)

                    // TEMP: Special Deals is hidden until this promotion area is ready.
                    // SectionHeader(title: LocaleKeys.home_special_deals.tr(), onAction: {})
                    //     .padding(.horizontal, AppSpacing.screenH)
                    // VGap(AppSpacing.md)
                    // SpecialDealsRow(promos: container.promoList.state.valueOrNull ?? [])
                    // VGap(AppSpacing.xl)

                    // 5. Popular Hotels — horizontal scroll.
                    SectionHeader(
                        title: LocaleKeys.home_popular_hotels.tr(),
                        onAction: { router.push(.hotel) }
                    )
                    .padding(.horizontal, AppSpacing.screenH)
                    VGap(AppSpacing.md)
                    PopularHotelsRow(hotels: container.hotelList.state.valueOrNull ?? [])
                    VGap(AppSpacing.xl)
                }
            }
            .ignoresSafeArea(edges: .top)
            .refreshable { await refreshHomeData(container) }
        }
        .background(AppColors.background.ignoresSafeArea())
    }
}

// ---------------------------------------------------------------------------
// Services
// ---------------------------------------------------------------------------

/// The product the home screen can search. Only `airTicket` is enabled for now.
enum ServiceType: String, CaseIterable, DartEnum {
    case airTicket, visa, tour, hotel

    /// Full name — used for the "coming soon" hints.
    var label: String {
        switch self {
        case .airTicket: return "Air Ticket"
        case .visa: return "Visa Service"
        case .tour: return "Tour Package"
        case .hotel: return "Hotel Booking"
        }
    }

    /// Short caption shown under each service tile.
    var shortLabel: String {
        switch self {
        case .airTicket: return "Air Ticket"
        case .visa: return "Visa"
        case .tour: return "Tour"
        case .hotel: return "Hotel"
        }
    }

    /// Solid (filled) icons for the tiles.
    var icon: IconData {
        switch self {
        case .airTicket: return Icons.flight_takeoff_rounded
        case .visa: return Icons.badge
        case .tour: return Icons.luggage
        case .hotel: return Icons.apartment
        }
    }

    /// Only Air Ticket is live; the rest show a "coming soon" hint when tapped.
    var enabled: Bool { self == .airTicket }
}

// ---------------------------------------------------------------------------
// 1. Green gradient header
// ---------------------------------------------------------------------------
private struct HeroHeader: View {
    let activeService: ServiceType
    let onServiceTap: (ServiceType) -> Void
    let unreadCount: Int
    /// `MediaQuery.of(context).padding.top`.
    let topPad: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App logo + notification bell share one line.
            HStack(alignment: .center, spacing: 0) {
                // Tint the logo solid white so it reads on the green
                // header. Swap to a real white asset when available.
                AppImage(AppAssets.brandLogo, height: 58, fit: .contain, tint: Colors.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                BellButton(unreadCount: unreadCount)
            }
            .padding(AppSpacing.screenH, topPad + 16, AppSpacing.screenH, 0)
            // Clear breathing room between the logo and the service cards.
            VGap(AppSpacing.xxl)
            // Service selector — horizontally scrollable row of product cards.
            ServiceSelector(active: activeService, onTap: onServiceTap)
            VGap(AppSpacing.sm)
        }
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                CoverAssetImage(path: AppAssets.header, fallback: Colors.transparent)
                // Dark scrim over the photo so the white logo/icons/text stay legible.
                LinearGradient(
                    colors: [Colors.black.withValues(alpha: 0.4), Colors.black.withValues(alpha: 0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
}

/// Reusable "Title ........ See More" row.
private struct SectionHeader: View {
    let title: String
    let onAction: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .textStyle(AppTypography.heading(19))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            HGap(8)
            Button(action: onAction) {
                Text(LocaleKeys.home_see_more.tr())
                    .textStyle(AppTypography.body(15, weight: .w600, color: AppColors.primary))
            }
            .buttonStyle(TextButtonStyle())
        }
    }
}

private struct BellButton: View {
    let unreadCount: Int

    @Environment(AppRouter.self) var router

    var body: some View {
        Icon(Icons.notifications_rounded, size: 24, color: Colors.white)
            .frame(width: 44, height: 44)
            .background(Circle().fill(Colors.white.withValues(alpha: 0.4)))
            .overlay(alignment: .topTrailing) {
                if unreadCount > 0 {
                    UnreadBadge(count: unreadCount)
                        .offset(x: 3, y: -3)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { router.push(.notifications) }
    }
}

/// Horizontally scrolling row of service cards. The active card is filled with
/// the brand green; the rest are white tiles that surface a "coming soon" hint.
private struct ServiceSelector: View {
    let active: ServiceType
    let onTap: (ServiceType) -> Void

    private static let hPad = AppSpacing.screenH

    var body: some View {
        // Center the tiles when they fit; fall back to horizontal scroll if
        // they ever exceed the available width.
        ViewThatFits(in: .horizontal) {
            cards.padding(.horizontal, Self.hPad)
            ScrollView(.horizontal, showsIndicators: false) {
                cards.padding(.horizontal, Self.hPad)
            }
            .scrollClipDisabled()
        }
        .frame(height: 96)
    }

    /// `Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly)`.
    private var cards: some View {
        HStack(spacing: 0) {
            ForEach(ServiceType.values, id: \.self) { s in
                Spacer(minLength: 0)
                ServiceCard(service: s, selected: s == active, onTap: { onTap(s) })
            }
            Spacer(minLength: 0)
        }
        .frame(height: 96)
    }
}

private struct ServiceCard: View {
    let service: ServiceType
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        let showHot = service == .airTicket
        VStack(spacing: 0) {
            Icon(service.icon, size: 27, color: selected ? Colors.white : AppColors.primary)
                .frame(width: 58, height: 58)
                .boxDecoration(
                    color: selected ? AppColors.accent : AppColors.surface,
                    radius: 17,
                    borderColor: selected ? nil : AppColors.border,
                    shadows: [
                        BoxShadow(
                            color: selected
                                ? AppColors.accent.withValues(alpha: 0.32)
                                : Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4)
                        ),
                    ]
                )
                // "Hot" flag on the Air Ticket tile.
                .overlay(alignment: .topTrailing) {
                    if showHot {
                        HotBadge().offset(x: 8, y: -7)
                    }
                }
            VGap(7)
            // Keep every label on a single line — scale down to fit the tile
            // so two-word names like "Hotel Booking" never wrap.
            Text(service.shortLabel)
                // Dark, bold ink + a soft white halo so the label stays
                // legible over the light gradient band.
                .textStyle(AppTypography.body(
                    11,
                    weight: selected ? .w800 : .w700,
                    color: selected ? AppColors.primaryDark : AppColors.textPrimary
                ))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .shadow(color: Colors.white.withValues(alpha: 0.9), radius: 3)
                .frame(maxWidth: .infinity)
        }
        .frame(width: 76)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

/// Small red "Hot" flag pinned to the corner of a service tile.
private struct HotBadge: View {
    var body: some View {
        HStack(spacing: 0) {
            Icon(Icons.star_rounded, size: 10, color: Colors.white)
            HGap(2)
            Text(LocaleKeys.home_hot.tr())
                .textStyle(AppTypography.body(8.5, weight: .w800, color: Colors.white))
        }
        .padding(horizontal: 6, vertical: 2)
        .boxDecoration(color: AppColors.error, radius: 8, borderColor: Colors.white, borderWidth: 1.2)
    }
}

/// Placeholder shown when a not-yet-built service is selected. (Air Ticket is
/// the only enabled service today, so this is effectively unreachable — it
/// exists so enabling another service later degrades gracefully.)
private struct ComingSoonCard: View {
    let service: ServiceType

    var body: some View {
        VStack(spacing: 0) {
            Icon(service.icon, size: 40, color: AppColors.primary)
            VGap(12)
            Text(LocaleKeys.home_is_coming_soon.tr(args: [service.label]))
                .textStyle(AppTypography.heading(16))
        }
        .padding(horizontal: 18, vertical: 36)
        .frame(maxWidth: .infinity)
        .boxDecoration(color: AppColors.surface, radius: 24, borderColor: AppColors.border)
    }
}

/// Round Trip / One Way segmented tabs at the top of the search card.
private struct TripTypeTabs: View {
    @Environment(AppContainer.self) var container

    var body: some View {
        // Rebuilds only when the trip type changes, not on every booking update.
        let tripType = container.flightBookingBloc.state.tripType
        HStack(spacing: 0) {
            tab(LocaleKeys.home_one_way.tr(), .oneWay, tripType == .oneWay)
            tab(LocaleKeys.home_round_trip.tr(), .roundTrip, tripType == .roundTrip)
        }
        .padding(4)
        .boxDecoration(color: AppColors.primarySurface, radius: 14)
    }

    private func tab(_ label: String, _ type: TripType, _ selected: Bool) -> some View {
        Text(label)
            .textStyle(AppTypography.body(
                13.5,
                weight: .w600,
                color: selected ? AppColors.primary : AppColors.textSecondary
            ))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .boxDecoration(
                color: selected ? AppColors.surface : Colors.transparent,
                radius: 10,
                shadows: selected
                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: Offset(0, 2))]
                    : []
            )
            // AnimatedContainer(duration: 200ms), linear by default.
            .animation(.linear(duration: 0.2), value: selected)
            .contentShape(Rectangle())
            .onTapGesture { container.flightBookingBloc.add(.tripTypeChanged(type)) }
    }
}

/// Domestic / International scope — inline radio-dot style inside the card.
private struct ScopeSelector: View {
    @Environment(AppContainer.self) var container

    var body: some View {
        let scope = container.flightBookingBloc.state.scope
        HStack(spacing: 0) {
            radio(LocaleKeys.home_domestic.tr(), .domestic, scope == .domestic)
            HGap(12)
            radio(LocaleKeys.home_international.tr(), .international, scope == .international)
        }
    }

    private func radio(_ label: String, _ scope: TravelScope, _ selected: Bool) -> some View {
        HStack(spacing: 0) {
            // Outer ring + animated inner fill.
            Circle()
                .fill(AppColors.primary)
                .frame(width: selected ? 7 : 0, height: selected ? 7 : 0)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .stroke(selected ? AppColors.primary : AppColors.textTertiary, lineWidth: 2)
                        .padding(1)
                )
                .animation(.linear(duration: 0.18), value: selected)
            HGap(5)
            Text(label)
                .textStyle(AppTypography.body(
                    12.5,
                    weight: selected ? .w700 : .w500,
                    color: selected ? AppColors.textPrimary : AppColors.textSecondary
                ))
        }
        .contentShape(Rectangle())
        .onTapGesture { container.flightBookingBloc.add(.travelScopeChanged(scope)) }
    }
}

/// Full-width Nationality dropdown — Myanmar or Other. Sits just above the
/// Search button and drives `FlightBookingState.nationality`, which every flight
/// search sends to the service.
private struct NationalityDropdown: View {
    /// Taller field + slightly larger text/icon (used by the Version 2 home).
    var large = false

    @Environment(AppContainer.self) var container
    /// The field's frame on screen, so the menu can open right under it.
    @State var fieldFrame: CGRect = .zero

    /// Opens the options anchored directly below the field, like the dropdowns on
    /// the traveller form, instead of overlaying the field itself.
    private func openMenu() async {
        let bloc = container.flightBookingBloc
        let current = bloc.state.nationality
        let field = fieldFrame
        let large = self.large

        let selected: Nationality? = await showDialog(barrierColor: Colors.transparent) { dismiss in
            AnchoredMenuLayout(anchor: field, onBarrierTap: { dismiss(nil) }) {
                VStack(spacing: 0) {
                    ForEach(Nationality.values, id: \.self) { nationality in
                        Button {
                            dismiss(nationality)
                        } label: {
                            Text(nationality.label)
                                .textStyle(AppTypography.body(
                                    13.5,
                                    weight: nationality == current ? .w700 : .w500,
                                    color: nationality == current ? AppColors.primaryDark : AppColors.textPrimary
                                ))
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .padding(.horizontal, 12)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.ink)
                    }
                }
                .padding(.vertical, 8)
                .frame(width: field.width)
                .boxDecoration(
                    color: AppColors.surface,
                    radius: large ? 4 : 14,
                    borderColor: AppColors.border,
                    shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: Offset(0, 3))]
                )
            }
        }
        if let selected { bloc.add(.nationalityChanged(selected)) }
    }

    var body: some View {
        let nationality = container.flightBookingBloc.state.nationality
        PickerField(
            label: LocaleKeys.booking_nationality.tr(),
            icon: Icons.flag_outlined,
            value: nationality.label,
            onTap: { Task { await openMenu() } },
            large: large,
            trailing: AnyView(
                Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary)
            )
        )
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { fieldFrame = proxy.frame(in: .global) }
                    .onChange(of: proxy.frame(in: .global)) { _, frame in fieldFrame = frame }
            }
        )
    }
}

/// Version 2 combined pill: shows the current trip type + scope on one line
/// and opens a bottom sheet to change either (mirrors the reference "Round-trip
/// | 1 traveler" control).
private struct TripScopePill: View {
    @Environment(AppContainer.self) var container

    var body: some View {
        let booking = container.flightBookingBloc.state
        let tripLabel = booking.tripType == .oneWay
            ? LocaleKeys.home_one_way.tr()
            : LocaleKeys.home_round_trip.tr()
        let scopeLabel = booking.scope == .domestic
            ? LocaleKeys.home_domestic.tr()
            : LocaleKeys.home_international.tr()

        HStack(spacing: 0) {
            // Left — trip type.
            pillSegment(Icons.swap_horiz_rounded, tripLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
            HGap(14)
            Rectangle().fill(AppColors.textTertiary).frame(width: 1.5, height: 22)
            HGap(14)
            // Right — scope.
            pillSegment(Icons.public, scopeLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(horizontal: 14, vertical: 11)
        .boxDecoration(color: v2FieldFill, radius: 6, borderColor: AppColors.border)
        .contentShape(Rectangle())
        .onTapGesture {
            let bloc = container.flightBookingBloc
            Task { await showTripScopeSheet(bloc) }
        }
    }

    private func pillSegment(_ icon: IconData, _ label: String) -> some View {
        HStack(spacing: 0) {
            Icon(icon, size: 18, color: AppColors.primary)
            HGap(8)
            Text(label)
                .textStyle(AppTypography.body(14, weight: .w700, color: AppColors.textPrimary))
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

/// Bottom sheet for the `TripScopePill` — choose One Way / Round Trip and
/// Domestic / International.
///
/// The sheet redraws through a BlocBuilder rather than `setState` after each
/// tap: `add` is asynchronous, so re-reading the state straight after it would
/// still show the old selection. (Swift: the sheet observes `bloc.state`.)
@MainActor
private func showTripScopeSheet(_ bloc: FlightBookingBloc) async {
    // The four options and confirmation button need more than the default
    // half-screen sheet on compact devices.
    let _: Bool? = await showModalBottomSheet(
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        topRadius: 24
    ) { dismiss in
        TripScopeSheet(bloc: bloc, onDone: { dismiss(nil) })
    }
}

/// The `BlocBuilder` body of the trip-options sheet.
private struct TripScopeSheet: View {
    let bloc: FlightBookingBloc
    let onDone: () -> Void

    var body: some View {
        let booking = bloc.state
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 4)
                .fill(AppColors.border)
                .frame(width: 40, height: 4)
                .frame(maxWidth: .infinity)
            VGap(20)
            Group {
                Text(LocaleKeys.home_trip_type.tr())
                    .textStyle(AppTypography.heading(18))
                VGap(4)
                RadioRow(
                    label: LocaleKeys.home_one_way.tr(),
                    selected: booking.tripType == .oneWay,
                    onTap: { bloc.add(.tripTypeChanged(.oneWay)) }
                )
                RadioRow(
                    label: LocaleKeys.home_round_trip.tr(),
                    selected: booking.tripType == .roundTrip,
                    onTap: { bloc.add(.tripTypeChanged(.roundTrip)) }
                )
            }
            VGap(12)
            MaterialDivider(height: 1, color: AppColors.dividerLight)
            VGap(12)
            Group {
                Text(LocaleKeys.home_scope.tr())
                    .textStyle(AppTypography.heading(18))
                VGap(4)
                RadioRow(
                    label: LocaleKeys.home_domestic.tr(),
                    selected: booking.scope == .domestic,
                    onTap: { bloc.add(.travelScopeChanged(.domestic)) }
                )
                RadioRow(
                    label: LocaleKeys.home_international.tr(),
                    selected: booking.scope == .international,
                    onTap: { bloc.add(.travelScopeChanged(.international)) }
                )
            }
            VGap(24)
            Button(action: onDone) {
                Text(LocaleKeys.home_done.tr())
                    .textStyle(AppTypography.body(16, weight: .w600, color: Colors.white))
            }
            .buttonStyle(ElevatedButtonStyle())
        }
        .padding(24, 12, 24, 28)
    }
}

/// A radio-style option row used inside the trip-options bottom sheet.
private struct RadioRow: View {
    let label: String
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(AppColors.primary)
                .frame(width: selected ? 12 : 0, height: selected ? 12 : 0)
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .stroke(selected ? AppColors.primary : AppColors.textTertiary, lineWidth: 2)
                        .padding(1)
                )
                .animation(.linear(duration: 0.16), value: selected)
            HGap(12)
            Text(label)
                .textStyle(AppTypography.body(
                    15,
                    weight: selected ? .w700 : .w500,
                    color: selected ? AppColors.textPrimary : AppColors.textSecondary
                ))
            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// ---------------------------------------------------------------------------
// 3. White air-ticket search card
// ---------------------------------------------------------------------------
private struct SearchCardBody: View {
    let onSearch: () -> Void

    /// Version 2 layout: a combined Trip-type + Scope pill (opening a bottom
    /// sheet) instead of the separate tabs + radios, and larger input fields.
    var v2 = false

    @Environment(AppContainer.self) var container
    @Environment(AppRouter.self) var router

    private func pickLocation(isFrom: Bool) async {
        let bloc = container.flightBookingBloc
        let booking = bloc.state
        let result = await router.pushForResult(
            .locationPicker(
                title: isFrom ? LocaleKeys.common_from.tr() : LocaleKeys.common_to.tr(),
                exclude: isFrom
                    ? (booking.isToLocationSelected ? booking.toLocation : nil)
                    : (booking.isFromLocationSelected ? booking.fromLocation : nil)
            ),
            as: LocationModel.self
        )
        guard let result else { return }
        bloc.add(isFrom ? .fromLocationChanged(result) : .toLocationChanged(result))
    }

    private func swapAction(_ booking: FlightBookingState) -> (() -> Void)? {
        guard booking.hasCompleteRoute else { return nil }
        let bloc = container.flightBookingBloc
        return { bloc.add(.locationsSwapped) }
    }

    var body: some View {
        let booking = container.flightBookingBloc.state
        let isRound = booking.tripType == .roundTrip
        let isBus = booking.mode == .bus

        let content = VStack(spacing: 0) {
            // Trip type + scope. V2 folds both into one tappable pill.
            if v2 {
                TripScopePill()
                VGap(12)
            } else {
                TripTypeTabs()
                VGap(12)
                ScopeSelector()
                    .frame(maxWidth: .infinity, alignment: .leading)
                VGap(12)
            }
            // From / To with overlapping swap button.
            VStack(spacing: 0) {
                LocationField(
                    label: LocaleKeys.common_from.tr(),
                    location: booking.fromLocation,
                    selected: booking.isFromLocationSelected,
                    isFrom: true,
                    icon: isBus ? Icons.directions_bus : Icons.flight_takeoff,
                    onTap: { Task { await pickLocation(isFrom: true) } },
                    large: v2
                )
                VGap(v2 ? 10 : 8)
                LocationField(
                    label: LocaleKeys.common_to.tr(),
                    location: booking.toLocation,
                    selected: booking.isToLocationSelected,
                    isFrom: false,
                    icon: isBus ? Icons.directions_bus : Icons.flight_land,
                    onTap: { Task { await pickLocation(isFrom: false) } },
                    large: v2
                )
            }
            .overlay(alignment: .trailing) {
                SwapButton(onTap: swapAction(booking))
                    .padding(.trailing, 8)
            }
            VGap(10)

            // Dates — Round Trip shows two fields; One Way fades to a single full-
            // width Departure field. AnimatedCrossFade handles the transition.
            ZStack(alignment: .top) {
                if isRound {
                    // V2 stacks Departure over Return (each full-width); V1 keeps them
                    // side by side.
                    Group {
                        if v2 {
                            VStack(spacing: 0) {
                                dateField(booking, isReturn: false)
                                VGap(12)
                                dateField(booking, isReturn: true)
                            }
                        } else {
                            HStack(spacing: 0) {
                                dateField(booking, isReturn: false)
                                    .frame(maxWidth: .infinity)
                                HGap(10)
                                dateField(booking, isReturn: true)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .transition(.opacity)
                } else {
                    dateField(booking, isReturn: false)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.28), value: isRound)
            VGap(v2 ? 12 : 10)

            // Traveller (+ Class for flights only — buses have no cabin class).
            HStack(spacing: 0) {
                PickerField(
                    label: LocaleKeys.home_traveller.tr(),
                    icon: Icons.person_outline,
                    value: travellerLabel(booking),
                    onTap: { Task { await pickTravellers() } },
                    large: v2
                )
                .frame(maxWidth: .infinity)
                if !isBus {
                    HGap(10)
                    PickerField(
                        label: LocaleKeys.common_class.tr(),
                        icon: Icons.airline_seat_recline_normal,
                        value: booking.cabinClass.label,
                        onTap: { Task { await pickClass() } },
                        large: v2
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            VGap(v2 ? 12 : 10)

            // Nationality, sitting just above the Search action.
            NationalityDropdown(large: v2)
            VGap(16)

            if v2 {
                Button(action: onSearch) {
                    HStack(spacing: 0) {
                        Icon(Icons.search_rounded, size: 20)
                        HGap(8)
                        Text(LocaleKeys.home_search_flights.tr())
                            .textStyle(AppTypography.body(16, weight: .w600, color: Colors.white))
                    }
                }
                // ElevatedButton.icon: 48pt tall, M3 icon-button padding (16 / 24).
                .buttonStyle(ElevatedButtonStyle(
                    minimumHeight: 48,
                    padding: EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 24)
                ))
            } else {
                Button(action: onSearch) {
                    Text(LocaleKeys.home_search.tr())
                        .textStyle(AppTypography.body(16, weight: .w600, color: Colors.white))
                }
                .buttonStyle(ElevatedButtonStyle())
            }
        }

        // V2 — a frosted-glass card: the hero photo blurs through a translucent
        // white fill with a soft light rim, for a premium look while the fields
        // stay perfectly readable.
        if v2 {
            content
                // Slim side padding so the fields stretch as wide as possible;
                // a tighter top inset so the One Way/Domestic pill sits closer
                // to the card's top edge.
                .padding(7, 10, 7, 16)
                .background {
                    ZStack {
                        // Heavier blur so the card dissolves into the hero photo.
                        Rectangle().fill(.ultraThinMaterial)
                        // A clear frosted-white panel, whiter at the top and easing off
                        // toward the bottom so it still melts into the photo edges.
                        LinearGradient(
                            colors: [Colors.white.withValues(alpha: 0.62), Colors.white.withValues(alpha: 0.40)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
                // Very soft lift, outside the clip so it isn't cropped.
                .boxDecoration(
                    radius: 12,
                    borderColor: Colors.white.withValues(alpha: 0.35),
                    shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 20, offset: Offset(0, 8))]
                )
        } else {
            // V1 — solid white card.
            content
                .padding(16)
                .boxDecoration(
                    color: AppColors.surface,
                    radius: 24,
                    shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: Offset(0, 10))]
                )
        }
    }

    private func pickDate(isReturn: Bool) async {
        let bloc = container.flightBookingBloc
        let booking = bloc.state
        let now = DateTime.now()
        let today = DateTime(now.year, now.month, now.day)
        let searchLastDate = today.add(Duration(days: 365))
        let firstDate = isReturn
            ? DateTime(booking.departDate.year, booking.departDate.month, booking.departDate.day)
            : today
        // Keep the departure day selectable for a same-day return, even when it
        // is at the search horizon.
        let lastDate = isReturn && firstDate.isAfter(searchLastDate) ? firstDate : searchLastDate
        let requestedInitial = isReturn ? (booking.returnDate ?? booking.departDate) : booking.departDate
        let initial = requestedInitial.isBefore(firstDate)
            ? firstDate
            : (requestedInitial.isAfter(lastDate) ? lastDate : requestedInitial)
        guard let picked = await pickHomeDate(initialDate: initial, firstDate: firstDate, lastDate: lastDate) else {
            return
        }
        bloc.add(isReturn ? .returnDateChanged(picked) : .departDateChanged(picked))
    }

    /// A date field. V1 is a tappable picker; V2 is an editable field (type a
    /// date or use the calendar icon).
    @ViewBuilder
    private func dateField(_ booking: FlightBookingState, isReturn: Bool) -> some View {
        let now = DateTime.now()
        let today = DateTime(now.year, now.month, now.day)
        let lastDate = today.add(Duration(days: 365))
        let bloc = container.flightBookingBloc

        if isReturn {
            let firstReturnDate = DateTime(booking.departDate.year, booking.departDate.month, booking.departDate.day)
            let returnLastDate = firstReturnDate.isAfter(lastDate) ? firstReturnDate : lastDate
            let value = booking.returnDate ?? firstReturnDate
            if v2 {
                DateInputV2(
                    label: LocaleKeys.common_return.tr(),
                    value: value,
                    firstDate: firstReturnDate,
                    lastDate: returnLastDate,
                    onChanged: { date in bloc.add(.returnDateChanged(date)) }
                )
            } else {
                PickerField(
                    label: LocaleKeys.common_return.tr(),
                    icon: Icons.calendar_today,
                    value: booking.returnDate.map { Formatters.numericDate($0) } ?? "Return",
                    onTap: { Task { await pickDate(isReturn: true) } }
                )
            }
        } else if v2 {
            DateInputV2(
                label: LocaleKeys.home_departure.tr(),
                value: booking.departDate,
                firstDate: today,
                lastDate: lastDate,
                onChanged: { date in bloc.add(.departDateChanged(date)) }
            )
        } else {
            PickerField(
                label: LocaleKeys.home_departure.tr(),
                icon: Icons.calendar_today,
                value: Formatters.numericDate(booking.departDate),
                onTap: { Task { await pickDate(isReturn: false) } }
            )
        }
    }

    /// Like the trip-scope sheet, this redraws through a BlocBuilder: the
    /// steppers' limits depend on the counts the bloc has just clamped.
    private func pickTravellers() async {
        let bloc = container.flightBookingBloc
        let _: Bool? = await showModalBottomSheet(backgroundColor: AppColors.surface, topRadius: 24) { dismiss in
            TravellersSheet(bloc: bloc, onDone: { dismiss(nil) })
        }
    }

    private func pickClass() async {
        let bloc = container.flightBookingBloc
        // Read once, before the sheet opens (no BlocBuilder here).
        let booking = bloc.state
        let _: Bool? = await showModalBottomSheet(backgroundColor: AppColors.surface, topRadius: 24) { dismiss in
            CabinClassSheet(
                current: booking.cabinClass,
                onPick: { c in
                    bloc.add(.cabinClassChanged(c))
                    dismiss(nil)
                }
            )
        }
    }
}

/// The `BlocBuilder` body of the traveller picker sheet.
private struct TravellersSheet: View {
    let bloc: FlightBookingBloc
    let onDone: () -> Void

    var body: some View {
        let booking = bloc.state
        VStack(spacing: 0) {
            Group {
                Text(LocaleKeys.home_travellers.tr())
                    .textStyle(AppTypography.heading(20))
                VGap(4)
                Text("Up to \(FlightBookingState.maxTravellers) travellers per booking")
                    .textStyle(AppTypography.body(12.5, color: AppColors.textSecondary))
                VGap(16)
            }
            PaxRow(
                title: LocaleKeys.home_adults.tr(),
                subtitle: "Aged 12+",
                count: booking.travellerCount,
                min: 1,
                max: booking.maxAdults,
                onChanged: { v in bloc.add(.adultCountChanged(v)) }
            )
            MaterialDivider(height: 22)
            PaxRow(
                title: LocaleKeys.home_children.tr(),
                subtitle: "Aged 2–11",
                count: booking.childCount,
                min: 0,
                max: booking.maxChildren,
                onChanged: { v in bloc.add(.childCountChanged(v)) }
            )
            MaterialDivider(height: 22)
            PaxRow(
                title: LocaleKeys.home_infants.tr(),
                subtitle: "Under 2 · on lap",
                count: booking.infantCount,
                min: 0,
                max: booking.maxInfants,
                onChanged: { v in bloc.add(.infantCountChanged(v)) }
            )
            VGap(24)
            Button(action: onDone) {
                Text(LocaleKeys.home_done.tr())
                    .textStyle(AppTypography.body(16, weight: .w600, color: Colors.white))
            }
            .buttonStyle(ElevatedButtonStyle())
        }
        .padding(24, 20, 24, 24)
    }
}

/// The cabin-class sheet: one `ListTile` per class.
private struct CabinClassSheet: View {
    let current: TravelClass
    let onPick: (TravelClass) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(LocaleKeys.home_cabin_class.tr())
                .textStyle(AppTypography.heading(20))
            VGap(12)
            ForEach(TravelClass.values, id: \.self) { c in
                Button {
                    onPick(c)
                } label: {
                    HStack(spacing: 0) {
                        Text(c.label)
                            .textStyle(AppTypography.body(15, weight: .w500))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HGap(16)
                        if current == c {
                            Icon(Icons.check_circle, color: AppColors.primary)
                        } else {
                            Icon(Icons.circle_outlined, color: AppColors.textTertiary)
                        }
                    }
                    // Material 3 ListTile: 56pt tall, 16 / 24 content padding.
                    .padding(.leading, 16)
                    .padding(.trailing, 24)
                    .frame(minHeight: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.ink)
            }
        }
        .padding(.vertical, 20)
    }
}

private struct LocationField: View {
    let label: String
    let location: LocationModel
    let selected: Bool
    let isFrom: Bool
    let icon: IconData
    let onTap: () -> Void

    /// Taller field + slightly larger text/icon (used by the Version 2 home).
    var large = false

    var body: some View {
        let placeholder = large
            ? (isFrom ? "Select departure airport" : "Select destination airport")
            : (isFrom ? "Select departure" : "Select destination")

        // V2: the label sits inside the box, above the value. V1: plain box.
        Group {
            if large {
                v2FieldBox(label: label) { row(placeholder) }
            } else {
                row(placeholder)
                    .padding(horizontal: 14, vertical: 13)
                    .boxDecoration(radius: 14, borderColor: AppColors.border)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }

    private func row(_ placeholder: String) -> some View {
        HStack(spacing: 0) {
            // V2 drops the leading icon for a cleaner field.
            if !large {
                Icon(icon, size: 20, color: AppColors.primary)
                HGap(10)
            }
            Group {
                if selected {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        // V2 shows the full airport name; V1 keeps the short city.
                        Text(large ? location.facilityName : location.city)
                            .textStyle(
                                large
                                    ? AppTypography.body(14, weight: .w600, color: AppColors.textPrimary)
                                    : AppTypography.heading(13.5)
                            )
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text(large ? ", \(location.code)" : "  \(location.code)")
                            .textStyle(AppTypography.body(large ? 11.5 : 12, weight: .w700, color: AppColors.primary))
                            .fixedSize()
                    }
                } else {
                    Text(placeholder)
                        .textStyle(AppTypography.body(large ? 14 : 13.5, weight: .w500, color: AppColors.textTertiary))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Spacer so text doesn't slide under the swap button.
            HGap(40)
        }
    }
}

/// Near-solid white fill for the v2 (glass-card) input boxes, so each field
/// reads as a crisp, clearly-defined panel over the frosted background.
private let v2FieldFill = Colors.white.withValues(alpha: 0.92)

/// Small caption sitting inside a v2 field, above its value.
private struct FieldLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        // Sentence case (as passed in) — no longer forced to all caps.
        Text(text)
            .textStyle(AppTypography.body(11, weight: .w500, color: AppColors.textSecondary))
    }
}

/// Fixed content-row height shared by every v2 field box (From/To, Departure/
/// Return, Traveller/Class) so they all render at exactly the same height,
/// regardless of whether the content is a Text row or a TextField.
private let v2FieldContentHeight: CGFloat = 22

/// A v2 glass-card input box with the label sitting *inside* it, above the
/// value — a clean, professional outlined field. `content` is clamped to
/// `v2FieldContentHeight` and vertically centred, so every field box in the
/// card ends up pixel-identical in height.
private func v2FieldBox<Content: View>(
    label: String,
    padding: EdgeInsets = EdgeInsets(top: 8, leading: 14, bottom: 10, trailing: 14),
    @ViewBuilder content: () -> Content
) -> some View {
    VStack(alignment: .leading, spacing: 0) {
        FieldLabel(label)
        VGap(3)
        // The clip is a safety net — if any content is ever a hair taller
        // than the fixed band, it's clipped here instead of bleeding up
        // into the label above.
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: v2FieldContentHeight, alignment: .leading)
            .clipped()
    }
    .padding(padding)
    .frame(maxWidth: .infinity, alignment: .leading)
    // Tighter corners so the boxes read crisp and squared-off.
    .boxDecoration(color: v2FieldFill, radius: 4, borderColor: AppColors.border)
}

private struct SwapButton: View {
    let onTap: (() -> Void)?

    var body: some View {
        let enabled = onTap != nil
        // Rotate the horizontal reverse arrows to point up/down (From ↕ To).
        AppImage(AppAssets.swapRoute, tint: enabled ? AppColors.primary : AppColors.textTertiary)
            .rotationEffect(.degrees(90))
            .padding(10)
            .frame(width: 40, height: 40)
            // White fill keeps it clean over the field seam; thin primary outline,
            // no coloured background, primary-tinted reverse icon.
            .boxDecoration(
                color: enabled ? AppColors.surface : AppColors.dividerLight,
                circle: true,
                borderColor: enabled ? AppColors.primary : AppColors.border,
                borderWidth: 1.5
            )
            .contentShape(Circle())
            .onTapGesture { onTap?() }
    }
}

private struct PickerField: View {
    let label: String
    let icon: IconData
    let value: String
    var onTap: (() -> Void)? = nil

    /// Taller field + slightly larger text/icon (used by the Version 2 home).
    var large = false

    /// Shown after the value, e.g. a dropdown's arrow.
    var trailing: AnyView? = nil

    var body: some View {
        // V2: the label sits inside the box, above the value. V1: plain box.
        Group {
            if large {
                v2FieldBox(label: label) { row }
            } else {
                row
                    .padding(horizontal: 12, vertical: 13)
                    .boxDecoration(radius: 14, borderColor: AppColors.border)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }

    private var row: some View {
        HStack(spacing: 0) {
            // V2 drops the leading icon for a cleaner field.
            if !large {
                Icon(icon, size: 16, color: AppColors.primary)
                HGap(8)
            }
            Text(value)
                .textStyle(AppTypography.body(
                    large ? 14 : 13.5,
                    weight: large ? .w500 : .w600,
                    color: AppColors.textPrimary
                ))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let trailing {
                trailing
            }
        }
    }
}

/// V2 date field: tap anywhere (or the calendar icon) to pick a date. The value
/// renders as plain `dd/mm/yyyy` text inside the shared field box — exactly like
/// the From / To fields — so Departure / Return stay pixel-identical in height
/// and never clip inside the fixed content band.
private struct DateInputV2: View {
    let label: String
    let value: DateTime
    let firstDate: DateTime
    let lastDate: DateTime
    let onChanged: (DateTime) -> Void

    private func clamp(_ d: DateTime) -> DateTime {
        if d.isBefore(firstDate) { return firstDate }
        if d.isAfter(lastDate) { return lastDate }
        return d
    }

    private func pick() async {
        let picked = await pickHomeDate(initialDate: clamp(value), firstDate: firstDate, lastDate: lastDate)
        if let picked { onChanged(picked) }
    }

    var body: some View {
        v2FieldBox(label: label) {
            HStack(spacing: 0) {
                Text(Formatters.numericDate(value))
                    .textStyle(AppTypography.body(14, weight: .w500, color: AppColors.textPrimary))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HGap(8)
                Icon(Icons.calendar_today, size: 18, color: AppColors.primary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { Task { await pick() } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }
}

private struct StepBtn: View {
    let icon: IconData
    let onTap: () -> Void

    var body: some View {
        Icon(icon, size: 20, color: AppColors.primary)
            .frame(width: 40, height: 40)
            .boxDecoration(color: AppColors.primarySurface, radius: 12)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
    }
}

/// One passenger-category row (Adults / Children / Infants) with a stepper.
/// The minus button is a no-op once `count` reaches `min`.
private struct PaxRow: View {
    let title: String
    let subtitle: String
    let count: Int
    let min: Int
    let max: Int
    let onChanged: (Int) -> Void

    var body: some View {
        let canDecrement = count > min
        let canIncrement = count < max
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .textStyle(AppTypography.body(16, weight: .w600))
                VGap(2)
                Text(subtitle)
                    .textStyle(AppTypography.body(12, color: AppColors.textPrimary))
            }
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                StepBtn(icon: Icons.remove, onTap: {
                    if canDecrement { onChanged(count - 1) }
                })
                .opacity(canDecrement ? 1 : 0.4)
                Text("\(count)")
                    .textStyle(AppTypography.heading(20))
                    .padding(.horizontal, 18)
                StepBtn(icon: Icons.add, onTap: {
                    if canIncrement { onChanged(count + 1) }
                })
                .opacity(canIncrement ? 1 : 0.4)
            }
        }
    }
}

/// Compact label for the traveller picker field. Shows the adult count alone
/// when there are no children/infants, otherwise the combined total.
private func travellerLabel(_ b: FlightBookingState) -> String {
    if b.childCount == 0 && b.infantCount == 0 {
        return "\(b.travellerCount) Adult\(b.travellerCount > 1 ? "s" : "")"
    }
    return "\(b.totalTravellers) Traveller\(b.totalTravellers > 1 ? "s" : "")"
}

// ---------------------------------------------------------------------------
// 4. Special Deals — horizontal scroll
// ---------------------------------------------------------------------------
// (Dart: `// ignore: unused_element` — kept while the section is hidden.)
private struct SpecialDealsRow: View {
    let promos: [PromoModel]

    var body: some View {
        if !promos.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(Array(promos.enumerated()), id: \.offset) { _, promo in
                        SpecialDealCard(promo: promo) {
                            SnackBarCenter.shared.show(
                                LocaleKeys.home_opening_deal.tr(args: [promo.title]),
                                floating: true
                            )
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.screenH)
            }
            .scrollClipDisabled()
            .frame(height: 168)
        }
    }
}

/// Full-width "Commercial flights" image card (V2 only). Just the c6.jpg
/// artwork — the label and "See More" action live in the section header above
/// it. Height matches the Special Deals cards.
private struct CommercialFlightsCard: View {
    @Environment(AppRouter.self) var router

    var body: some View {
        CoverAssetImage(path: AppAssets.hotelSample, fallback: AppColors.primarySurface)
            .frame(maxWidth: .infinity)
            .frame(height: 168)
            .boxDecoration(
                radius: 20,
                shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 14, offset: Offset(0, 6))]
            )
            .contentShape(Rectangle())
            .onTapGesture { router.push(.commercialFlight) }
    }
}

private struct SpecialDealCard: View {
    let promo: PromoModel
    let onTap: () -> Void

    var body: some View {
        let isFlight = promo.type == .flight
        ZStack {
            NetworkImage(promo.imageUrl, width: 286, height: 168, fit: .cover) {
                AppColors.primarySurface
            } error: {
                AppColors.primarySurface
                    .overlay { Icon(Icons.image_outlined, color: AppColors.textTertiary) }
            }
            LinearGradient(
                colors: [Colors.black.withValues(alpha: 0.72), Colors.black.withValues(alpha: 0.15)],
                startPoint: .leading,
                endPoint: .trailing
            )
            VStack(alignment: .leading, spacing: 0) {
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
        .frame(width: 286, height: 168)
        .boxDecoration(
            radius: 20,
            shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 14, offset: Offset(0, 6))]
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
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

// ---------------------------------------------------------------------------
// 5. Popular Hotels — horizontal scroll
// ---------------------------------------------------------------------------
private struct PopularHotelsRow: View {
    let hotels: [HotelModel]

    var body: some View {
        if !hotels.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(Array(hotels.enumerated()), id: \.offset) { _, hotel in
                        HotelCard(hotel: hotel) {
                            Task {
                                let _: Bool? = await showModalBottomSheet(backgroundColor: Colors.transparent) { _ in
                                    HotelDetailsSheet(hotel: hotel)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.screenH)
            }
            .scrollClipDisabled()
            .frame(height: 220)
        }
    }
}

private struct HotelCard: View {
    let hotel: HotelModel
    let onTap: () -> Void

    /// `rating.toStringAsFixed(1)`.
    private static let ratingFormat = NumberFormat("0.0")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Photo with a rating chip.
            NetworkImage(hotel.imageUrl, width: 286, height: 132, fit: .cover) {
                AppColors.primarySurface
            } error: {
                AppColors.primarySurface
                    .overlay { Icon(Icons.image_outlined, color: AppColors.textTertiary) }
            }
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 0) {
                    Icon(Icons.star_rounded, size: 14, color: AppColors.accent)
                    HGap(3)
                    Text(Self.ratingFormat.format(hotel.rating))
                        .textStyle(AppTypography.body(11, weight: .w700, color: Colors.white))
                }
                .padding(horizontal: 8, vertical: 4)
                .boxDecoration(color: Colors.black.withValues(alpha: 0.55), radius: 30)
                .padding(.top, 10)
                .padding(.trailing, 10)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(hotel.name)
                    .textStyle(AppTypography.heading(15))
                    .lineLimit(1)
                    .truncationMode(.tail)
                VGap(3)
                HStack(spacing: 0) {
                    Icon(Icons.location_on_outlined, size: 13, color: AppColors.textTertiary)
                    HGap(3)
                    Text(hotel.location)
                        .textStyle(AppTypography.body(11, color: AppColors.textPrimary))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12, 10, 12, 12)
        }
        .frame(width: 286, height: 220, alignment: .top)
        .boxDecoration(
            color: AppColors.surface,
            radius: 20,
            borderColor: AppColors.border,
            shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: Offset(0, 6))]
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// ===========================================================================
// HOME PAGE — VERSION 2 (shown when signed in with the v2 account)
// ===========================================================================

/// A redesigned, single-screen home: a banner hero with the colour logo, the
/// service selector (with an About tab), and a larger air-ticket search card —
/// everything visible without scrolling on a typical phone.
struct HomePageV2: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router

    @State private var activeService: ServiceType = .airTicket
    /// `initState` runs once; `.task` would run on every reappearance.
    @State private var didRunInitialCheck = false

    init() {}

    private func startSearch() {
        let bloc = container.flightBookingBloc
        let booking = bloc.state
        if !booking.hasCompleteRoute {
            showRouteRequiredMessage()
            return
        }
        // Populate the results, then show them beneath the branded loader: the
        // loader is a transparent overlay that blurs the results screen behind it
        // and pops itself when the animation completes, revealing the results.
        bloc.add(.flightSearchRequested)
        router.push(.searchResults)
        router.push(.flightSearchLoading(from: booking.fromLocation, to: booking.toLocation))
    }

    private func onServiceTap(_ service: ServiceType) {
        switch service {
        case .visa:
            router.push(.visa)
        case .tour:
            router.push(.tour)
        case .hotel:
            router.push(.hotel)
        case .airTicket:
            activeService = .airTicket
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Full-bleed hero (~2/3 of the viewport) over the bg photo — it
                    // carries the logo, actions, service row AND the search card.
                    HeroHeaderV2(
                        active: activeService,
                        onServiceTap: onServiceTap,
                        unreadCount: container.unreadNotificationCount,
                        searchCard: SearchCardBody(onSearch: startSearch, v2: true),
                        topPad: proxy.safeAreaInsets.top,
                        minHeight: homeScreenHeight * 2 / 3
                    )
                    VGap(AppSpacing.xl)

                    // Commercial flights — header ("Commercial flights" + "see all")
                    // above a full-width image card (V2 only).
                    SectionHeader(
                        title: LocaleKeys.home_commercial_flights.tr(),
                        onAction: { router.push(.commercialFlight) }
                    )
                    .padding(.horizontal, AppSpacing.screenH)
                    VGap(AppSpacing.md)
                    CommercialFlightsCard()
                        .padding(.horizontal, AppSpacing.screenH)
                    VGap(AppSpacing.xl)

                    // TEMP: Special Deals is hidden until this promotion area is ready.
                    // SectionHeader(title: LocaleKeys.home_special_deals.tr(), onAction: {})
                    //     .padding(.horizontal, AppSpacing.screenH)
                    // VGap(AppSpacing.md)
                    // SpecialDealsRow(promos: container.promoList.state.valueOrNull ?? [])
                    // VGap(AppSpacing.xl)

                    // Popular Hotels — same as the user home.
                    SectionHeader(
                        title: LocaleKeys.home_popular_hotels.tr(),
                        onAction: { router.push(.hotel) }
                    )
                    .padding(.horizontal, AppSpacing.screenH)
                    VGap(AppSpacing.md)
                    PopularHotelsRow(hotels: container.hotelList.state.valueOrNull ?? [])
                    VGap(AppSpacing.xl)
                }
            }
            .ignoresSafeArea(edges: .top)
            .refreshable { await refreshHomeData(container) }
        }
        .background(Colors.white.ignoresSafeArea())
        .task {
            // Landing here as a guest (not signed in): greet with the sign-up prompt
            // before anything else. Authenticated users skip it.
            guard !didRunInitialCheck else { return }
            didRunInitialCheck = true
            if !container.authNotifier.state.isAuthenticated {
                await showSignUpPrompt(router: router)
            }
        }
    }
}

/// Hero (~2/3 of the viewport): the b7.jpg photo with a graduated overlay
/// carries the colour logo, the notification + phone actions, the service
/// selector AND the air-ticket search card — all layered on the image.
private struct HeroHeaderV2<SearchCard: View>: View {
    let active: ServiceType
    let onServiceTap: (ServiceType) -> Void
    let unreadCount: Int
    let searchCard: SearchCard
    /// `MediaQuery.of(context).padding.top`.
    let topPad: CGFloat
    /// `MediaQuery.of(context).size.height * 2 / 3`.
    let minHeight: CGFloat

    @Environment(AppRouter.self) var router

    var body: some View {
        // Foreground content, all sitting on the photo.
        VStack(alignment: .leading, spacing: 0) {
            // Pull the content up close to the status bar (red-line target).
            VGap(topPad > 24 ? topPad - 8 : topPad)
            // Full-colour logo + phone / message / notification actions.
            HStack(spacing: 0) {
                // Logo in its natural colours; Expanded + FittedBox keep
                // it left-aligned and never overflow.
                AppImage(AppAssets.brandLogo, height: 56)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HGap(8)
                // Notifications — a red dot signals unread items.
                CircleIconBtn(
                    icon: Icons.notifications_none_rounded,
                    onTap: { router.push(.notifications) },
                    badgeCount: unreadCount
                )
                HGap(8)
                // Combined contact action — opens a dropdown with the
                // phone & message options over a dim black scrim.
                CircleIconBtn(
                    icon: Icons.perm_phone_msg_outlined,
                    onTap: { Task { await showContactMenu() } }
                )
            }
            .frame(height: 62)
            .padding(.horizontal, 20)
            VGap(16)
            ServiceRowV2(active: active, onServiceTap: onServiceTap)
            VGap(10)
            // Air-ticket search card, on top of the photo. Tighter side
            // inset than the rest of the page so the card — and every
            // field inside it — reads noticeably wider.
            searchCard
                .padding(.horizontal, 10)
            VGap(22)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .top)
        .background {
            ZStack {
                // Background photo (Dart `Transform.flip(flipX: false)` — not flipped).
                CoverAssetImage(path: AppAssets.tourSample, fallback: AppColors.primaryDark)
                // Graduated overlay: pure white at the top so the colour logo pops,
                // fading through the photo to no tint at all by the bottom of the
                // hero — a bright, premium header.
                LinearGradient(
                    stops: [
                        .init(color: Colors.white.withValues(alpha: 0.95), location: 0.0),
                        .init(color: Colors.white.withValues(alpha: 0.55), location: 0.30),
                        .init(color: Colors.white.withValues(alpha: 0.0), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        // Rounded bottom corners so the hero reads as a card.
        .clipShape(UnevenRoundedRectangle(cornerRadii: BorderRadius.only(bottomLeft: 20, bottomRight: 20)))
    }
}

/// Small circular action button used in the v2 hero. A count badge appears
/// only while there are unread notifications.
private struct CircleIconBtn: View {
    let icon: IconData
    let onTap: () -> Void
    var badgeCount = 0

    var body: some View {
        Icon(icon, size: 19, color: AppColors.primary)
            .frame(width: 38, height: 38)
            // White button with a soft lift + brand-green icon, so it reads on
            // the white top band beside the colour logo.
            .boxDecoration(
                color: Colors.white,
                circle: true,
                shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: Offset(0, 2))]
            )
            .overlay(alignment: .topTrailing) {
                if badgeCount > 0 {
                    UnreadBadge(count: badgeCount)
                        .offset(x: 5, y: -5)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
    }
}

/// Compact numeric badge shared by both home notification controls.
private struct UnreadBadge: View {
    let count: Int

    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .textStyle(AppTypography.body(9, weight: .w800, color: Colors.white))
            .padding(.horizontal, 4)
            .frame(minWidth: 17, minHeight: 17)
            .boxDecoration(color: Color(0xFFFF3B30), radius: 10, borderColor: Colors.white, borderWidth: 1.5)
    }
}

/// Drops a small contact menu (Message / Call) under the header action button,
/// dimming everything behind it with a translucent black scrim. Tapping the
/// scrim or a row closes the menu.
@MainActor
private func showContactMenu() async {
    let _: Bool? = await showDialog(barrierColor: Colors.black.withValues(alpha: 0.55)) { dismiss in
        GeneralDialogLayout(onBarrierTap: { dismiss(nil) }) { topInset in
            ContactMenuCard(
                onViber: {
                    dismiss(nil)
                    Task { await ContactLauncher.viber(AppConsts.hotlinePhone) }
                },
                onMessenger: {
                    dismiss(nil)
                    Task { await ContactLauncher.messenger(AppConsts.messengerPage) }
                },
                onCall: {
                    dismiss(nil)
                    Task { await ContactLauncher.dial(AppConsts.hotlinePhone) }
                }
            )
            .padding(.top, topInset + 60)
            .padding(.trailing, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
    }
}

/// White rounded card holding the contact options, one per row.
private struct ContactMenuCard: View {
    let onViber: () -> Void
    let onMessenger: () -> Void
    let onCall: () -> Void

    private static let dividerColor = Color(0xFFEFEFEF)

    var body: some View {
        VStack(spacing: 0) {
            ContactMenuRow(
                svg: AppAssets.channelViber,
                color: Color(0xFF7360F2),
                title: "Viber",
                subtitle: AppConsts.hotlinePhone,
                onTap: onViber
            )
            MaterialDivider(height: 1, thickness: 1, color: Self.dividerColor, indent: 68, endIndent: 14)
            ContactMenuRow(
                svg: AppAssets.channelMessenger,
                color: Color(0xFF0084FF),
                title: "Messenger",
                subtitle: "m.me/\(AppConsts.messengerPage)",
                onTap: onMessenger
            )
            MaterialDivider(height: 1, thickness: 1, color: Self.dividerColor, indent: 68, endIndent: 14)
            ContactMenuRow(
                svg: AppAssets.channelCall,
                color: Color(0xFF12A150),
                title: LocaleKeys.home_call_us.tr(),
                subtitle: AppConsts.hotlinePhone,
                onTap: onCall
            )
        }
        .frame(width: 250)
        .boxDecoration(
            color: Colors.white,
            radius: 18,
            shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 24, offset: Offset(0, 10))]
        )
    }
}

/// One tappable contact row: a colourful, background-less 3D icon glyph +
/// title/subtitle.
private struct ContactMenuRow: View {
    let svg: String
    let color: Color
    let title: String
    let subtitle: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Brand-coloured channel glyph (Viber / phone), no background badge.
                AppImage(svg, width: 30, height: 30, tint: color)
                    .frame(width: 44, height: 44)
                HGap(12)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .textStyle(AppTypography.body(15, weight: .w600))
                    VGap(1)
                    Text(subtitle)
                        .textStyle(AppTypography.body(12, color: AppColors.textPrimary))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textTertiary)
            }
            .padding(horizontal: 14, vertical: 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.ink(radius: 18))
    }
}

/// Guest sign-up nudge shown over a dim scrim when the home page opens without
/// an authenticated session. "Sign Up" routes to the login form; "Later"
/// dismisses. Deliberately Epic-World branded (green membership theme).
@MainActor
private func showSignUpPrompt(router: AppRouter) async {
    let _: Bool? = await showDialog(barrierColor: Colors.black.withValues(alpha: 0.42)) { dismiss in
        GeneralDialogLayout(onBarrierTap: { dismiss(nil) }) { _ in
            ZStack {
                // Softly blur the home screen behind the prompt.
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .opacity(0.6)
                    .allowsHitTesting(false)
                SignUpPromptCard(
                    onLater: { dismiss(nil) },
                    onSignUp: {
                        dismiss(nil)
                        router.push(.login())
                    }
                )
            }
        }
    }
}

/// The card body of the guest sign-up prompt. Styled after the "newsletter"
/// reference: a green ray-burst header with a floating illustration, a big bold
/// title, supporting copy and the actions — no email field.
private struct SignUpPromptCard: View {
    let onLater: () -> Void
    let onSignUp: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Illustration badge floating in the burst.
            AppImage(AppAssets.rewardBanner, fit: .contain)
                .padding(18)
                .frame(width: 96, height: 96)
                .boxDecoration(
                    color: Colors.white,
                    circle: true,
                    shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 18, offset: Offset(0, 8))]
                )
                .padding(.top, 46)
                .padding(.bottom, 22)
            VStack(spacing: 0) {
                Text(LocaleKeys.home_join_epic_world_rewards.tr())
                    .textStyle(AppTypography.heading(24, weight: .w800, height: 1.2))
                    .multilineTextAlignment(.center)
                VGap(12)
                Text(LocaleKeys.home_sign_up_to_collect_points_on.tr())
                    .textStyle(AppTypography.body(14, color: AppColors.textSecondary, height: 1.55))
                    .multilineTextAlignment(.center)
                VGap(24)
                // Prominent full-width Sign Up (image-2 style) with a soft glow.
                Button(action: onSignUp) {
                    Text(LocaleKeys.common_sign_up.tr())
                        .textStyle(AppTypography.heading(16, color: Colors.white))
                }
                .buttonStyle(ElevatedButtonStyle(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumHeight: 56,
                    cornerRadius: 16
                ))
                .frame(height: 56)
                .boxDecoration(
                    radius: 16,
                    shadows: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.32), blurRadius: 18, offset: Offset(0, 8))]
                )
                VGap(6)
                // Secondary dismiss, kept subtle beneath the primary action.
                Button(action: onLater) {
                    Text(LocaleKeys.home_later.tr())
                        .textStyle(AppTypography.body(15, weight: .w600))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TextButtonStyle(foregroundColor: AppColors.textSecondary))
                .frame(height: 44)
            }
            .padding(26, 4, 26, 22)
        }
        .frame(maxWidth: 340)
        // Ray-burst background spanning the whole card. The painter tints
        // only the top region and dissolves to transparent, so there is no
        // separate header box to seam against the body below.
        .background {
            RewardRaysPainter()
                .allowsHitTesting(false)
        }
        .boxDecoration(
            color: Colors.white,
            radius: 28,
            shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 34, offset: Offset(0, 16))]
        )
        .padding(.horizontal, 24)
    }
}

/// Paints the green sun-ray burst behind the sign-up illustration: a radial
/// green glow overlaid with soft white wedges, fading to white at the bottom so
/// it blends into the card body.
private struct RewardRaysPainter: View {
    /// Drives the slow, seamless rotation of the ray-burst shade behind the badge
    /// (one 3-second loop, repeated).
    private static let period: TimeInterval = 3

    @State var start = Date()

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(start)
                .truncatingRemainder(dividingBy: Self.period) / Self.period
            Canvas { canvas, size in
                paint(canvas, size: size, t: t)
            }
        }
    }

    private func paint(_ canvas: GraphicsContext, size: CGSize, t: Double) {
        let rect = CGRect(origin: .zero, size: size)
        // Anchor the burst near the top (behind the badge); it covers the top band
        // and fades out well above the title.
        let focal = CGPoint(x: size.width / 2, y: 92)
        let radius = size.width * 1.25

        // Paint the burst into its own layer so we can dissolve it to *transparent*
        // toward the bottom. It sits over the card's white fill, so there is only
        // one white surface — no second rectangle to seam against the body.
        canvas.drawLayer { layer in
            // Base radial green glow, lighter at the focal point.
            layer.fill(
                Path(rect),
                with: .radialGradient(
                    Gradient(colors: [Color.lerp(AppColors.primary, Colors.white, 0.28), AppColors.primary]),
                    center: focal,
                    startRadius: 0,
                    endRadius: radius
                )
            )

            // Rotating white sun-ray wedges (every other sector). The rotation period is
            // one sector-pair (2π / 10), so a 0→1 loop returns to the same pattern —
            // the repeat is seamless.
            let count = 20
            let rot = t * (2 * Double.pi / Double(count / 2))
            let rayColor = Colors.white.withValues(alpha: 0.10)
            for i in stride(from: 0, to: count, by: 2) {
                let a0 = Double(i) * 2 * Double.pi / Double(count) + rot
                let a1 = a0 + (2 * Double.pi / Double(count))
                var path = Path()
                path.move(to: focal)
                path.addLine(to: CGPoint(x: focal.x + radius * cos(a0), y: focal.y + radius * sin(a0)))
                path.addLine(to: CGPoint(x: focal.x + radius * cos(a1), y: focal.y + radius * sin(a1)))
                path.closeSubpath()
                layer.fill(path, with: .color(rayColor))
            }

            // Alpha mask: keep the burst up top, fade it to fully transparent ~158px
            // down (above the title) so the white card behind shows through — no line.
            let h = max(size.height, 158)
            layer.blendMode = .destinationIn
            layer.fill(
                Path(rect),
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: Colors.black, location: 0.0),
                        .init(color: Colors.black, location: 108 / h),
                        .init(color: Color(0x00000000), location: 158 / h),
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
        }
    }
}

/// Service selector for v2: Air Ticket · Visa · Tour · Hotel (About moved to
/// the bottom nav).
private struct ServiceRowV2: View {
    let active: ServiceType
    let onServiceTap: (ServiceType) -> Void

    var body: some View {
        // Keep the usual centred group on normal screens while allowing
        // a safe horizontal scroll on unusually narrow screens.
        ViewThatFits(in: .horizontal) {
            tiles
                .frame(maxWidth: .infinity)
            ScrollView(.horizontal, showsIndicators: false) {
                tiles
            }
        }
        .padding(.horizontal, AppSpacing.screenH)
        .frame(height: 94)
    }

    private var tiles: some View {
        HStack(spacing: 0) {
            ForEach(ServiceType.values, id: \.self) { s in
                ServiceTileV2(
                    icon: s.icon,
                    label: s.shortLabel,
                    selected: s == active,
                    hot: s == .airTicket,
                    onTap: { onServiceTap(s) }
                )
                if s != ServiceType.values.last {
                    HGap(10)
                }
            }
        }
        .frame(height: 94)
    }
}

private struct ServiceTileV2: View {
    let icon: IconData
    let label: String
    let selected: Bool
    let hot: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Icon(icon, size: 27, color: selected ? Colors.white : AppColors.primary)
                .frame(width: 60, height: 60)
                // Active tile uses the logo's amber; others stay white with
                // a hairline border so they read on the white top band.
                .boxDecoration(
                    color: selected ? AppColors.accent : AppColors.surface,
                    radius: 18,
                    borderColor: selected ? nil : AppColors.border,
                    shadows: [
                        BoxShadow(
                            color: selected
                                ? AppColors.accent.withValues(alpha: 0.40)
                                : Colors.black.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: Offset(0, 4)
                        ),
                    ]
                )
                .overlay(alignment: .topTrailing) {
                    if hot {
                        HotBadge().offset(x: 8, y: -7)
                    }
                }
            VGap(7)
            // Ultra bold ink + a soft white halo so the label stays legible
            // even where the photo peeks through the white band.
            Text(label)
                .textStyle(AppTypography.body(
                    11,
                    weight: .w900,
                    color: selected ? AppColors.primaryDark : AppColors.textPrimary
                ))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .shadow(color: Colors.white.withValues(alpha: 0.9), radius: 3)
                .frame(maxWidth: .infinity)
        }
        .frame(width: 72)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// ---------------------------------------------------------------------------
// Flutter overlay helpers (showGeneralDialog / showMenu / showDatePicker)
// ---------------------------------------------------------------------------

/// `showGeneralDialog` content: undoes `ModalHost`'s dialog insets and the safe
/// area so the builder lays out against the whole screen, as Flutter's general
/// dialogs do. `topInset` is `MediaQuery.of(context).padding.top`.
private struct GeneralDialogLayout<Content: View>: View {
    let onBarrierTap: () -> Void
    @ViewBuilder let content: (_ topInset: CGFloat) -> Content

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onBarrierTap)
                content(proxy.safeAreaInsets.top)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .padding(.horizontal, -40)
        .padding(.vertical, -24)
        .ignoresSafeArea()
    }
}

/// `showMenu(position: RelativeRect…)`: the menu card placed 4pt under the
/// `anchor` field (screen coordinates), left edges aligned.
private struct AnchoredMenuLayout<Content: View>: View {
    let anchor: CGRect
    let onBarrierTap: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            let origin = proxy.frame(in: .global).origin
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onBarrierTap)
                content()
                    .offset(x: anchor.minX - origin.x, y: anchor.maxY + 4 - origin.y)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .padding(.horizontal, -40)
        .padding(.vertical, -24)
        .ignoresSafeArea()
    }
}

/// `showDatePicker(initialDate:, firstDate:, lastDate:)`: the Material date
/// dialog (white surface, 28pt corners) with Cancel / OK. Resolves to the
/// picked day at local midnight, or nil when dismissed.
@MainActor
private func pickHomeDate(initialDate: DateTime, firstDate: DateTime, lastDate: DateTime) async -> DateTime? {
    await showDialog { (dismiss: @escaping (DateTime?) -> Void) in
        HomeDatePickerDialog(
            initialDate: initialDate,
            firstDate: firstDate,
            lastDate: lastDate,
            onClose: { dismiss($0) }
        )
    }
}

private struct HomeDatePickerDialog: View {
    let firstDate: DateTime
    let lastDate: DateTime
    let onClose: (DateTime?) -> Void

    @State private var selection: Date

    init(initialDate: DateTime, firstDate: DateTime, lastDate: DateTime, onClose: @escaping (DateTime?) -> Void) {
        self.firstDate = firstDate
        self.lastDate = lastDate
        self.onClose = onClose
        _selection = State(initialValue: initialDate.date)
    }

    var body: some View {
        VStack(spacing: 0) {
            DatePicker(
                "",
                selection: $selection,
                in: firstDate.date...max(firstDate.date, lastDate.date),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(AppColors.primary)
            .padding(12, 12, 12, 0)
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Button {
                    onClose(nil)
                } label: {
                    Text("Cancel")
                        .textStyle(AppTypography.labelLarge.copyWith(color: AppColors.primary))
                }
                .buttonStyle(TextButtonStyle())
                HGap(8)
                Button {
                    onClose(DateTime(date: selection).dateOnly)
                } label: {
                    Text("OK")
                        .textStyle(AppTypography.labelLarge.copyWith(color: AppColors.primary))
                }
                .buttonStyle(TextButtonStyle())
            }
            .padding(12, 0, 12, 12)
        }
        .boxDecoration(color: AppColors.surface, radius: 28)
    }
}

/// `Image.asset(path, fit: BoxFit.cover)` filling the space it is given, with
/// the `errorBuilder` colour when the asset is missing.
private struct CoverAssetImage: View {
    let path: String
    let fallback: Color

    var body: some View {
        Color.clear
            .overlay {
                if AppImage.image(for: path) != nil {
                    AppImage(path, fit: .cover)
                } else {
                    fallback
                }
            }
            .clipped()
    }
}
