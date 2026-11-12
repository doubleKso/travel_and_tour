// Port of lib/features/booking/presentation/pages/search_results_page.dart

import SwiftUI

/// SEARCH RESULTS — stage 2 (Detail) of the progress tracker.
///
/// Flow on entry: a brief **progress state** (skeleton cards) shows first, then
/// the searched flights are revealed. A green route header carries the
/// From ✈ To title, the horizontal step tracker sits beneath it, and a date
/// strip (with per-day fares) + filter lets the user refine the list. Selecting
/// an option advances toward payment. For round-trips, the user picks the
/// outbound first, then the return leg, then proceeds to payment.
struct SearchResultsPage: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router

    /// The date strip is hidden by default — only the progress state shows. The
    /// header's date button reveals it.
    @State private var showDates = false
    /// `initState` runs once; `.task` would run again each time the page
    /// reappears after a pushed route is popped.
    @State private var initialized = false

    init() {}

    var body: some View {
        let bloc = container.flightBookingBloc
        let booking = bloc.state
        let isPickingReturn = booking.tripType == .roundTrip
            && booking.selectedOutbound != nil
            && booking.selectedInbound == nil
        let from = isPickingReturn ? booking.toLocation : booking.fromLocation
        let to = isPickingReturn ? booking.fromLocation : booking.toLocation

        VStack(spacing: 0) {
            // Green route header with the From ✈ To title + date toggle button.
            RouteHeader(
                isPickingReturn: isPickingReturn,
                fromCity: from.code,
                toCity: to.code,
                dateText: Formatters.shortDate(booking.activeDate),
                travellers: booking.totalTravellers,
                flightCount: booking.results.count,
                datesShown: showDates,
                onToggleDates: { showDates.toggle() }
            )
            // Horizontal step tracker — same left/right inset as the cards.
            BookingProgressTracker(current: booking.stage)
                .padding(AppSpacing.screenH, 10, AppSpacing.screenH, 10)
                .frame(maxWidth: .infinity)
                .background(AppColors.surface)
            MaterialDivider(height: 1, color: AppColors.border)
            // Full-width departure summary — sits directly below the progress
            // tracker while the user picks the return leg.
            if isPickingReturn, let outbound = booking.selectedOutbound {
                ReturnSelectedBanner(outbound: outbound)
            }
            // Date strip (per-day fares) — appears directly under the progress
            // bar when the header's date button is tapped.
            VStack(spacing: 0) {
                if showDates {
                    VStack(spacing: 0) {
                        DateFilterBar(
                            activeDate: booking.activeDate,
                            onSelected: { d in bloc.add(.resultsReloaded(date: d)) }
                        )
                        MaterialDivider(height: 1, color: AppColors.border)
                    }
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity)
            .clipped()
            .animation(.linear(duration: 0.22), value: showDates)
            // Found-flights count + filter.
            FoundFilterBar()
            // Results list, or the progress state while loading.
            Group {
                if booking.isLoading {
                    SkeletonResults()
                } else {
                    ResultsList(isPickingReturn: isPickingReturn)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AppColors.background.ignoresSafeArea())
        // While choosing the return leg, the back arrow shouldn't leave the
        // screen — it should drop back to the departure-selection state.
        .popScope(canPop: !isPickingReturn) { didPop in
            if !didPop {
                bloc.add(.outboundSelectionRestarted)
            }
        }
        .onAppear {
            guard !initialized else { return }
            initialized = true
            // Show the progress state first, then reveal the flights.
            Task { @MainActor in
                if bloc.state.results.isEmpty { bloc.add(.resultsReloaded()) }
            }
        }
    }
}

/// The scrolling flight-card list.
private struct ResultsList: View {
    let isPickingReturn: Bool

    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router

    var body: some View {
        let booking = container.flightBookingBloc.state
        if booking.results.isEmpty {
            EmptyResults()
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    // ListView.builder: rows keyed by position, so a card's state
                    // follows its index and `didUpdateWidget` (onChange of the
                    // option id) resets the chosen fare.
                    ForEach(Array(booking.results.enumerated()), id: \.offset) { _, option in
                        let selected = isPickingReturn
                            ? booking.selectedInbound?.id == option.id
                            : booking.selectedOutbound?.id == option.id
                        TripOptionCard(
                            option: option,
                            onTap: { chosenOption in onSelect(chosenOption, isPickingReturn) },
                            selected: selected,
                            enquiryOnly: !FlightBookingState.isBookableOption(option)
                        )
                    }
                }
                .padding(AppSpacing.screenH, 14, AppSpacing.screenH, AppSpacing.screenH)
            }
        }
    }

    @MainActor
    private func onSelect(_ option: TripOptionModel, _ isPickingReturn: Bool) {
        let bloc = container.flightBookingBloc
        let before = bloc.state
        bloc.add(isPickingReturn ? .inboundSelected(option) : .outboundSelected(option))

        // `add` is asynchronous: `bloc.state` still holds the pre-selection value
        // here, so decide from that what the selection is about to produce. A
        // round trip with no return leg yet means this was the outbound pick and
        // the return list comes next.
        let needsReturnSelection = before.tripType == .roundTrip
            && !isPickingReturn
            && before.selectedInbound == nil

        // Round-trip & still need a return leg -> swap to the return list
        // instantly (no loading spinner — the data is already local). Events are
        // handled in order, so the refresh already sees the outbound pick.
        if needsReturnSelection {
            bloc.add(.resultsRefreshed)
            SnackBarCenter.shared.show(
                LocaleKeys.booking_departure_selected_now_choose_return_flight.tr(),
                backgroundColor: AppColors.primaryDark,
                floating: true
            )
            return
        }

        router.push(.bookingDetail)
    }
}

/// Shown if filters exclude every option.
private struct EmptyResults: View {
    var body: some View {
        VStack(spacing: 0) {
            Icon(Icons.search_off_rounded, size: 48, color: AppColors.textTertiary)
            VGap(12)
            Text(LocaleKeys.booking_no_flights_match_filters.tr())
                .textStyle(AppTypography.body(14, weight: .w600, color: AppColors.textSecondary))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// ---------------------------------------------------------------------------
// Progress state — a slim bar plus shimmering skeleton cards.
// ---------------------------------------------------------------------------

private struct SkeletonResults: View {
    /// `AnimationController(duration: 1100ms)..repeat(reverse: true)`.
    @State private var start = Date()

    var body: some View {
        VStack(spacing: 0) {
            // Indeterminate progress bar makes the "searching" state explicit.
            IndeterminateLinearProgress(
                backgroundColor: AppColors.divider,
                valueColor: AppColors.accent
            )
            .frame(height: 3)
            VGap(10)
            TimelineView(.animation) { context in
                let period = 1.1
                let elapsed = context.date.timeIntervalSince(start).truncatingRemainder(dividingBy: period * 2)
                let pulse = elapsed < period ? elapsed / period : 2 - elapsed / period
                let opacity = 0.45 + pulse * 0.45
                VStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { _ in
                        SkeletonCard().opacity(opacity)
                    }
                }
                .padding(.horizontal, AppSpacing.screenH)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .clipped()
            }
        }
    }
}

/// A grey placeholder shaped like the compact flight card.
private struct SkeletonCard: View {
    private static let bar = Color(0xFFE6E9EF)

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                block(38, 22)
                Spacer(minLength: 0)
                VStack(spacing: 0) {
                    block(70, 10)
                    VGap(8)
                    block(90, 8)
                }
                Spacer(minLength: 0)
                block(38, 22)
            }
            .padding(16, 14, 16, 12)
            MaterialDivider(height: 1, color: AppColors.divider)
                .padding(.horizontal, 14)
            HStack(spacing: 0) {
                block(30, 30, radius: 8)
                HGap(10)
                block(110, 12)
                Spacer(minLength: 0)
                block(90, 16)
            }
            .padding(14, 10, 16, 11)
        }
        .boxDecoration(color: AppColors.surface, radius: 18, borderColor: Color(0xFFECEEF3))
        .padding(.bottom, 12)
    }

    private func block(_ w: CGFloat, _ h: CGFloat, radius: CGFloat = 6) -> some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(Self.bar)
            .frame(width: w, height: h)
    }
}

/// Flutter's indeterminate `LinearProgressIndicator`: two bars sweeping across
/// the track on the Material 1800 ms cycle.
private struct IndeterminateLinearProgress: View {
    let backgroundColor: Color
    let valueColor: Color

    @State private var start = Date()

    private static let duration = 1.8
    private static let line1Head = CurveInterval(0, 750.0 / 1800, Cubic(0.2, 0.0, 0.8, 1.0))
    private static let line1Tail = CurveInterval(333.0 / 1800, (333.0 + 750.0) / 1800, Cubic(0.4, 0.0, 1.0, 1.0))
    private static let line2Head = CurveInterval(1000.0 / 1800, (1000.0 + 567.0) / 1800, Cubic(0.0, 0.0, 0.65, 1.0))
    private static let line2Tail = CurveInterval(1267.0 / 1800, (1267.0 + 533.0) / 1800, Cubic(0.10, 0.0, 0.45, 1.0))

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(start)
                .truncatingRemainder(dividingBy: Self.duration) / Self.duration
            Canvas { canvas, size in
                canvas.fill(Path(CGRect(origin: .zero, size: size)), with: .color(backgroundColor))
                let w = Double(size.width)
                let x1 = w * Self.line1Tail.transform(t)
                let width1 = w * Self.line1Head.transform(t) - x1
                let x2 = w * Self.line2Tail.transform(t)
                let width2 = w * Self.line2Head.transform(t) - x2
                // drawBar(x1, width1); drawBar(x2, width2) — skipped when empty.
                for (x, width) in [(x1, width1), (x2, width2)] where width > 0 {
                    canvas.fill(
                        Path(CGRect(x: x, y: 0, width: width, height: Double(size.height))),
                        with: .color(valueColor)
                    )
                }
            }
        }
    }
}

/// Flutter's `Cubic(a, b, c, d)` easing curve (same bisection as Flutter).
private struct Cubic {
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
        if t <= 0 || t >= 1 { return Swift.min(Swift.max(t, 0), 1) }
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

/// Flutter's `Interval(begin, end, curve:)`.
private struct CurveInterval {
    let begin: Double
    let end: Double
    let curve: Cubic

    init(_ begin: Double, _ end: Double, _ curve: Cubic) {
        self.begin = begin
        self.end = end
        self.curve = curve
    }

    func transform(_ t: Double) -> Double {
        let local = Swift.min(Swift.max((t - begin) / (end - begin), 0), 1)
        if local == 0 || local == 1 { return local }
        return curve.transform(local)
    }
}

// ---------------------------------------------------------------------------
// Found-flights count + filter  (under the progress bar)
// ---------------------------------------------------------------------------

/// The result count with a "cheapest first" hint on the left and the filter
/// trigger on the right.
private struct FoundFilterBar: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        let booking = container.flightBookingBloc.state
        let count = booking.results.count
        let noun = booking.mode == .bus ? "Bus" : "Flight"
        let activeFilters = [
            booking.maxStops != nil,
            booking.classFilter != nil,
            booking.maxPrice != nil,
            booking.airlineFilter.map { !$0.isEmpty } ?? false,
            booking.departureTimeFilter.map { !$0.isEmpty } ?? false,
        ].filter { $0 }.count

        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                (
                    Text("\(count) ")
                        .styled(AppTypography.heading(17, color: AppColors.primaryDark))
                        + Text("\(noun)\(count == 1 ? "" : "s") Found")
                        .styled(AppTypography.body(13.5, weight: .w500, color: AppColors.textSecondary))
                )
                VGap(1)
                HStack(spacing: 0) {
                    Icon(
                        booking.sortByPriceAsc ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        size: 12,
                        color: AppColors.textTertiary
                    )
                    HGap(3)
                    Text(booking.sortByPriceAsc ? "Cheapest first" : "Highest first")
                        .textStyle(AppTypography.body(11.5, weight: .w500, color: AppColors.textPrimary))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            FilterButton(activeCount: activeFilters)
        }
        .padding(AppSpacing.screenH, 12, 12, 8)
        .background(AppColors.background)
    }
}

// ---------------------------------------------------------------------------
// Date strip (per-day fares)
// ---------------------------------------------------------------------------

/// A pinned month label and the horizontally-scrolling date strip (each day
/// shows its lowest fare). Revealed by the header's date button.
private struct DateFilterBar: View {
    let activeDate: DateTime
    let onSelected: (DateTime) -> Void

    @Environment(AppContainer.self) private var container

    var body: some View {
        let booking = container.flightBookingBloc.state

        HStack(spacing: 0) {
            // Pinned month label.
            VStack(spacing: 0) {
                Text(DateFormat("MMM").format(activeDate).uppercased())
                    .textStyle(AppTypography.heading(13, color: AppColors.accent, letterSpacing: 0.5))
                Text(DateFormat("y").format(activeDate))
                    .textStyle(AppTypography.body(10, weight: .w600, color: AppColors.textPrimary))
            }
            .padding(.leading, AppSpacing.screenH)
            .padding(.trailing, 14)
            Rectangle()
                .fill(AppColors.divider)
                .frame(width: 1, height: 34)
            // Scrolling date chips with per-day fares.
            DateSelectorStrip(
                selectedDate: activeDate,
                onSelected: onSelected,
                priceForDate: { d in booking.minPriceOn(d) }
            )
            .frame(maxWidth: .infinity)
            HGap(AppSpacing.screenH)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(AppColors.surface)
    }
}

/// Circular filter trigger with an active-count badge. Opens `FilterSheet`.
private struct FilterButton: View {
    let activeCount: Int

    @Environment(AppContainer.self) private var container

    var body: some View {
        let active = activeCount > 0
        Icon(Icons.tune_rounded, size: 20, color: active ? Colors.white : AppColors.primary)
            .frame(width: 44, height: 44)
            .boxDecoration(
                color: active ? nil : AppColors.primarySurface,
                gradient: active ? AppColors.primaryGradient : nil,
                radius: 13,
                shadows: active
                    ? [
                        BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.30),
                            blurRadius: 8,
                            offset: Offset(0, 3)
                        ),
                    ]
                    : []
            )
            .overlay(alignment: .topTrailing) {
                if active {
                    Text("\(activeCount)")
                        .textStyle(AppTypography.body(10, weight: .w800, color: Colors.white))
                        .frame(width: 18, height: 18)
                        .boxDecoration(
                            color: AppColors.accent,
                            circle: true,
                            borderColor: AppColors.surface,
                            borderWidth: 1.5
                        )
                        .offset(x: 4, y: -4)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { Task { await open() } }
    }

    @MainActor
    private func open() async {
        let bloc = container.flightBookingBloc
        let booking = bloc.state
        // Sized from the unfiltered response, never from the visible rows: a
        // ceiling derived from already-filtered results shrinks each time a price
        // filter is applied, which pinned the slider to its max and silently
        // dropped the filter on the next apply.
        let ceiling = booking.priceCeiling > 0 ? booking.priceCeiling + 50000 : 1000000.0
        var airlineSet = booking.availableAirlines
        for result in booking.results {
            let name = result.operatorName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { airlineSet.insert(name) }
        }
        if let filter = booking.airlineFilter { airlineSet.formUnion(filter) }
        let airlines = airlineSet.sorted()
        let result = await FilterSheet.show(
            initial: FilterResult(
                maxStops: booking.maxStops,
                travelClass: booking.classFilter,
                maxPrice: booking.maxPrice,
                airlines: booking.airlineFilter,
                departureTimes: booking.departureTimeFilter,
                sortAscending: booking.sortByPriceAsc
            ),
            priceCeiling: ceiling,
            availableAirlines: airlines,
            availableAirlineLogoUrls: booking.availableAirlineLogoUrls,
            availableAirlineCodes: booking.availableAirlineCodes
        )
        if let result {
            // Handled in order: the sort is in place before the filtered reload.
            bloc.add(.sortOrderChanged(ascending: result.sortAscending))
            bloc.add(
                .filtersApplied(
                    maxStops: result.maxStops,
                    classFilter: result.travelClass,
                    maxPrice: result.maxPrice,
                    airlines: result.airlines,
                    departureTimes: result.departureTimes
                )
            )
        }
    }
}

/// Full-width yellow summary of the already-chosen departure, shown while the
/// user picks the return leg. Purely informational: a label on the left and the
/// departure route + time/date on the right.
private struct ReturnSelectedBanner: View {
    let outbound: TripOptionModel

    @Environment(AppContainer.self) private var container

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left — label on top, a small frosted-glass Change button beneath.
            // Tapping Change resets the selection and drops back to the
            // departure-flight choosing state.
            VStack(alignment: .leading, spacing: 0) {
                Text(LocaleKeys.booking_departure_flight.tr())
                    .textStyle(AppTypography.body(15, weight: .w800, color: Colors.white))
                VGap(6)
                HStack(spacing: 0) {
                    Icon(Icons.swap_horiz_rounded, size: 13, color: Colors.white)
                    HGap(3)
                    Text(LocaleKeys.booking_change.tr())
                        .textStyle(AppTypography.body(11, weight: .w700, color: Colors.white))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                // Frosted-glass over the amber band.
                .boxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    radius: 20,
                    borderColor: Colors.white.withValues(alpha: 0.55)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    container.flightBookingBloc.add(.outboundSelectionRestarted)
                }
            }
            Spacer(minLength: 0)
            // Right — the chosen departure route and time/date, right-aligned.
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(outbound.originCode)  →  \(outbound.destinationCode)")
                    .textStyle(AppTypography.heading(15, color: Colors.white))
                VGap(2)
                Text("\(Formatters.time(outbound.departure))  ·  \(Formatters.shortDate(outbound.departure))")
                    .textStyle(AppTypography.body(11, weight: .w600, color: Colors.white.withValues(alpha: 0.92)))
            }
        }
        .padding(.horizontal, AppSpacing.screenH)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                // Lighter brand green so the band reads bright, not dark.
                colors: [AppColors.primaryLight, AppColors.accent],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
}

/// Green, square-cornered route header — the back button, a centred
/// `From ✈ To` title with a date · travellers · flights subtitle, and a date
/// button on the right that reveals / hides the date strip.
private struct RouteHeader: View {
    let isPickingReturn: Bool
    let fromCity: String
    let toCity: String
    let dateText: String
    let travellers: Int
    let flightCount: Int
    let datesShown: Bool
    let onToggleDates: () -> Void

    @Environment(AppRouter.self) private var router

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Button {
                Task { await router.maybePop() }
            } label: {
                Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            VStack(spacing: 0) {
                // From ✈ To title.
                HStack(spacing: 0) {
                    Text(fromCity)
                        .textStyle(AppTypography.heading(18, color: Colors.white))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.trailing)
                    Icon(Icons.flight_takeoff_rounded, size: 17, color: Colors.white)
                        .padding(.horizontal, 8)
                    Text(toCity)
                        .textStyle(AppTypography.heading(18, color: Colors.white))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                VGap(3)
                // date · travellers · flights subtitle.
                Text(
                    "\(dateText)  ·  \(travellers) \(travellers == 1 ? "Traveller" : "Travellers")  ·  "
                        + "\(flightCount) \(flightCount == 1 ? "Flight" : "Flights")"
                )
                .textStyle(AppTypography.body(11.5, weight: .w500, color: Colors.white.withValues(alpha: 0.85)))
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            // Date toggle button (reveals / hides the date strip).
            Icon(Icons.calendar_month_rounded, size: 21, color: Colors.white)
                .frame(width: 40, height: 40)
                .boxDecoration(color: Colors.white.withValues(alpha: datesShown ? 0.26 : 0.12), radius: 12)
                .animation(.linear(duration: 0.2), value: datesShown)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .onTapGesture(perform: onToggleDates)
        }
        .padding(6, 6, 6, 16)
        .frame(maxWidth: .infinity)
        .background(AppColors.heroGradient.ignoresSafeArea(edges: .top))
    }
}
