// Port of lib/features/booking/presentation/bloc/flight_booking_bloc.dart

import Foundation
import Observation

/// Drives the search → detail → payment → completed flow.
///
/// The one BLoC in an otherwise Riverpod app. The container still builds it
/// from the booking use cases (`container.flightBookingBloc`, see
/// `FlightBookingBridge.swift`), so this class knows nothing about the
/// container.
///
/// `FlightBookingState.stage` is what `BookingProgressTracker` reads to
/// highlight the current step; the checkout events below move it.
///
/// Concurrency: handlers run concurrently (the bloc default) except
/// `resultsReloaded` and the daily-price refresh, which are `restartable` — a
/// newer one cancels the one in flight, so a stale reload can never land on
/// top of a fresher one.
///
/// As in `package:bloc`, `add` is asynchronous: each event is handled in its
/// own main-actor task, in the order the events were added, so `state` still
/// holds the previous value straight after `add` returns. A handler's
/// `emit.isDone` check is `Task.isCancelled` (a restartable handler that was
/// superseded, or a closed bloc), and a cancelled handler's emits are dropped.
@MainActor
@Observable
final class FlightBookingBloc {
    private(set) var state: FlightBookingState

    @ObservationIgnored private let submitFlightSearch: SubmitFlightSearchUseCase
    @ObservationIgnored private let searchTrips: SearchTripsUseCase
    @ObservationIgnored private let getDailyMinPrices: GetDailyMinPricesUseCase

    /// Dart `Bloc.isClosed`.
    @ObservationIgnored private(set) var isClosed = false

    /// Handlers still running, so `close()` can cancel them.
    @ObservationIgnored private var handlers: [UUID: Task<Void, Never>] = [:]
    /// The latest task of each `restartable()` handler.
    @ObservationIgnored private var restartableHandlers: [RestartableHandler: Task<Void, Never>] = [:]
    /// Subscribers of `stream`.
    @ObservationIgnored private var listeners: [UUID: AsyncStream<FlightBookingState>.Continuation] = [:]

    private enum RestartableHandler: Hashable {
        case resultsReloaded
        case dailyMinPricesRequested
    }

    init(
        submitFlightSearch: SubmitFlightSearchUseCase,
        searchTrips: SearchTripsUseCase,
        getDailyMinPrices: GetDailyMinPricesUseCase
    ) {
        self.submitFlightSearch = submitFlightSearch
        self.searchTrips = searchTrips
        self.getDailyMinPrices = getDailyMinPrices
        state = FlightBookingState.initial()
    }

    /// The results screen shows a brief skeleton state before flights appear,
    /// both on first entry and whenever the date changes.
    private static let reloadDelay = Duration(milliseconds: 700)

    // MARK: - Bloc API

    /// Dart `bloc.add(event)` — the `on<Event>(handler)` table.
    func add(_ event: FlightBookingEvent) {
        // Dart throws a StateError for an event added after `close()`; a closed
        // bloc ignores it here.
        guard !isClosed else { return }
        switch event {
        // Search criteria
        case .travelModeChanged(let mode):
            dispatch { self.onTravelModeChanged(mode) }
        case .travelScopeChanged(let scope):
            dispatch { self.emit(self.state.copyWith(scope: scope)) }
        case .tripTypeChanged(let tripType):
            dispatch { self.onTripTypeChanged(tripType) }
        case .departDateChanged(let date):
            dispatch { self.setSearchDate(date, isReturn: false) }
        case .returnDateChanged(let date):
            dispatch { self.onReturnDateChanged(date) }
        case .fromLocationChanged(let location):
            dispatch { self.onFromLocationChanged(location) }
        case .toLocationChanged(let location):
            dispatch { self.onToLocationChanged(location) }
        case .locationsSwapped:
            dispatch { self.onLocationsSwapped() }
        case .adultCountChanged(let count):
            dispatch { self.onAdultCountChanged(count) }
        case .childCountChanged(let count):
            dispatch {
                self.emit(self.state.copyWith(childCount: min(max(count, 0), self.state.maxChildren)))
            }
        case .infantCountChanged(let count):
            dispatch {
                self.emit(self.state.copyWith(infantCount: min(max(count, 0), self.state.maxInfants)))
            }
        case .cabinClassChanged(let cabinClass):
            dispatch { self.emit(self.state.copyWith(cabinClass: cabinClass)) }
        case .nationalityChanged(let nationality):
            dispatch { self.emit(self.state.copyWith(nationality: nationality)) }

        // Results
        case .flightSearchRequested:
            dispatch { await self.onFlightSearchRequested() }
        case .resultsRefreshed:
            dispatch { await self.loadResults(stage: .detail) }
        case .resultsReloaded(let date):
            dispatch(restartable: .resultsReloaded) { await self.onResultsReloaded(date) }
        case .activeDateSelected(let date):
            dispatch { await self.onActiveDateSelected(date) }
        case .dailyMinPricesRequested:
            dispatch(restartable: .dailyMinPricesRequested) { await self.onDailyMinPricesRequested() }
        case .sortOrderChanged(let ascending):
            dispatch { self.onSortOrderChanged(ascending) }
        case let .filtersApplied(maxStops, classFilter, maxPrice, airlines, departureTimes):
            dispatch {
                await self.onFiltersApplied(
                    maxStops: maxStops,
                    classFilter: classFilter,
                    maxPrice: maxPrice,
                    airlines: airlines,
                    departureTimes: departureTimes
                )
            }

        // Selection & checkout
        case .outboundSelected(let option):
            dispatch { self.emit(self.state.copyWith(selectedOutbound: option)) }
        case .inboundSelected(let option):
            dispatch { self.emit(self.state.copyWith(selectedInbound: option)) }
        case .commercialFlightEnquiryStarted(let option):
            dispatch { self.onCommercialFlightEnquiryStarted(option) }
        case .outboundSelectionRestarted:
            dispatch { await self.onOutboundSelectionRestarted() }
        case .continuedToPayment:
            dispatch { self.emit(self.state.copyWith(stage: .payment)) }
        case .returnedFromConfirmation:
            dispatch {
                self.emit(
                    self.state.copyWith(
                        stage: .detail,
                        clearHoldRequest: true,
                        clearHoldResponse: true
                    )
                )
            }
        case .holdRequestSaved(let request):
            dispatch {
                self.emit(self.state.copyWith(holdRequest: request, clearHoldResponse: true))
            }
        case let .heldReservationConfirmed(request, response):
            dispatch {
                self.emit(
                    self.state.copyWith(
                        stage: .confirmation,
                        holdRequest: request,
                        holdResponse: response
                    )
                )
            }
        case let .heldBookingResumed(
            from, to, departDate, adults, children, infants,
            cabinClass, outbound, inbound, holdRequest, holdResponse, stage
        ):
            dispatch {
                self.onHeldBookingResumed(
                    from: from,
                    to: to,
                    departDate: departDate,
                    adults: adults,
                    children: children,
                    infants: infants,
                    cabinClass: cabinClass,
                    outbound: outbound,
                    inbound: inbound,
                    holdRequest: holdRequest,
                    holdResponse: holdResponse,
                    stage: stage
                )
            }
        case .returnedFromPayment:
            dispatch { self.emit(self.state.copyWith(stage: .confirmation)) }
        case .bookingCompleted:
            dispatch { self.emit(self.state.copyWith(stage: .completed)) }
        case .bookingReset:
            dispatch { self.onBookingReset() }
        }
    }

    /// Dart `bloc.stream`: every state emitted from now on.
    var stream: AsyncStream<FlightBookingState> {
        AsyncStream { continuation in
            if self.isClosed {
                continuation.finish()
                return
            }
            let id = UUID()
            self.listeners[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in self?.listeners[id] = nil }
            }
        }
    }

    /// Dart `bloc.close()`: stops taking events, cancels every handler still
    /// running (their emitters are done, so nothing they emit lands) and ends
    /// `stream`. Like Dart, it does not wait for a cancelled handler's own
    /// awaits to finish.
    func close() async {
        guard !isClosed else { return }
        isClosed = true
        handlers.values.forEach { $0.cancel() }
        handlers.removeAll()
        restartableHandlers.removeAll()
        listeners.values.forEach { $0.finish() }
        listeners.removeAll()
    }

    /// Runs one handler in its own main-actor task. `restartable` handlers
    /// cancel the previous task of the same event type first (Dart
    /// `transformer: restartable()`).
    private func dispatch(
        restartable key: RestartableHandler? = nil,
        _ handler: @escaping @MainActor () async -> Void
    ) {
        let id = UUID()
        let previous = key.flatMap { restartableHandlers[$0] }
        let task = Task { @MainActor [weak self] in
            previous?.cancel()
            await handler()
            self?.handlers[id] = nil
        }
        handlers[id] = task
        if let key { restartableHandlers[key] = task }
    }

    /// Dart `emit(state)`. A cancelled handler (Dart: a cancelled emitter) or a
    /// closed bloc drops the state.
    private func emit(_ newState: FlightBookingState) {
        guard !isClosed, !Task.isCancelled else { return }
        state = newState
        for listener in listeners.values { listener.yield(newState) }
    }

    // MARK: - Search criteria

    private func onTravelModeChanged(_ mode: TravelMode) {
        // Bus is domestic-only per the brief.
        emit(
            state.copyWith(
                mode: mode,
                scope: mode == .bus ? .domestic : state.scope
            )
        )
    }

    private func onTripTypeChanged(_ type: TripType) {
        emit(
            state.copyWith(
                tripType: type,
                returnDate: type == .roundTrip && state.returnDate == nil
                    ? Self.calendarDay(state.departDate)
                    : nil,
                clearReturnDate: type == .oneWay
            )
        )
    }

    /// Changing either date makes every previously selected leg invalid. In
    /// particular, a round trip must not retain its old return flight after the
    /// customer chooses a new outbound date (or vice versa).
    private func onReturnDateChanged(_ date: DateTime?) {
        guard let date else {
            let returnDateChanged = state.returnDate != nil
            emit(
                state.copyWith(
                    clearReturnDate: true,
                    clearOutbound: returnDateChanged,
                    clearInbound: returnDateChanged,
                    clearHoldRequest: returnDateChanged,
                    clearHoldResponse: returnDateChanged
                )
            )
            return
        }
        setSearchDate(date, isReturn: true)
    }

    private static func isSameCalendarDay(_ first: DateTime, _ second: DateTime) -> Bool {
        first.year == second.year && first.month == second.month && first.day == second.day
    }

    private static func calendarDay(_ date: DateTime) -> DateTime {
        DateTime(date.year, date.month, date.day)
    }

    private static func isBeforeCalendarDay(_ date: DateTime, _ reference: DateTime) -> Bool {
        calendarDay(date).isBefore(calendarDay(reference))
    }

    private func setSearchDate(_ date: DateTime, isReturn: Bool) {
        // A return can be on the same calendar day as departure, but never before
        // it. The date picker enforces this too, while this guard keeps
        // programmatic updates from creating an invalid search state.
        if isReturn && Self.isBeforeCalendarDay(date, state.departDate) { return }

        let previousDate = isReturn ? state.returnDate : state.departDate
        let dateChanged = previousDate.map { !Self.isSameCalendarDay($0, date) } ?? true
        let adjustedReturnDate: DateTime?
        if !isReturn, let returnDate = state.returnDate, Self.isBeforeCalendarDay(returnDate, date) {
            adjustedReturnDate = Self.calendarDay(date)
        } else {
            adjustedReturnDate = nil
        }

        emit(
            state.copyWith(
                departDate: isReturn ? nil : date,
                returnDate: isReturn ? date : adjustedReturnDate,
                // An unchanged date should preserve the current itinerary; a real
                // date change requires the customer to choose both round-trip legs
                // again.
                clearOutbound: dateChanged,
                clearInbound: dateChanged,
                clearHoldRequest: dateChanged,
                clearHoldResponse: dateChanged
            )
        )
    }

    private func onFromLocationChanged(_ location: LocationModel) {
        // Avoid From == To.
        let swapLocations = state.isToLocationSelected && location.code == state.toLocation.code
        emit(
            state.copyWith(
                fromLocation: location,
                toLocation: swapLocations ? state.fromLocation : state.toLocation,
                isFromLocationSelected: true,
                isToLocationSelected: swapLocations ? state.isFromLocationSelected : state.isToLocationSelected
            )
        )
    }

    private func onToLocationChanged(_ location: LocationModel) {
        let swapLocations = state.isFromLocationSelected && location.code == state.fromLocation.code
        emit(
            state.copyWith(
                fromLocation: swapLocations ? state.toLocation : state.fromLocation,
                toLocation: location,
                isFromLocationSelected: swapLocations ? state.isToLocationSelected : state.isFromLocationSelected,
                isToLocationSelected: true
            )
        )
    }

    private func onLocationsSwapped() {
        if !state.hasCompleteRoute { return }
        emit(
            state.copyWith(
                fromLocation: state.toLocation,
                toLocation: state.fromLocation,
                isFromLocationSelected: state.isToLocationSelected,
                isToLocationSelected: state.isFromLocationSelected
            )
        )
    }

    // Counts are clamped so the booking never holds more than
    // `FlightBookingState.maxTravellers` people in total.
    private func onAdultCountChanged(_ count: Int) {
        let adults = min(max(count, 1), state.maxAdults)
        emit(
            state.copyWith(
                travellerCount: adults,
                // Infants can't outnumber adults (lap-held), so keep them in sync.
                infantCount: state.infantCount > adults ? adults : state.infantCount
            )
        )
    }

    // MARK: - Results

    /// Runs a search and moves the tracker to the detail stage.
    ///
    /// The cabin class chosen on the search form seeds
    /// `FlightBookingState.classFilter` so the results list opens on the class
    /// that was actually asked for. Without this the list is unfiltered and —
    /// sorted cheapest-first — leads with Economy even when Business was
    /// picked. The filter sheet's "Any" option is how the customer widens it
    /// back out.
    private func onFlightSearchRequested() async {
        // This is the Home form's entry point. A flight picked during an earlier
        // visit must never make the matching card look selected when the
        // customer starts a fresh search with the same route.
        emit(
            state.copyWith(
                isLoading: true,
                classFilter: state.cabinClass,
                clearOutbound: true,
                clearInbound: true,
                clearHoldRequest: true,
                clearHoldResponse: true
            )
        )
        await loadResults(stage: .detail)
        requestDailyMinPrices()
    }

    private static func pad(_ value: Int, _ width: Int) -> String {
        let digits = String(value)
        return String(repeating: "0", count: max(0, width - digits.count)) + digits
    }

    private static func dateOnly(_ date: DateTime) -> String {
        "\(pad(date.year, 4))-\(pad(date.month, 2))-\(pad(date.day, 2))"
    }

    /// The date applies immediately so the selected chip highlights while the
    /// list is still loading. `restartable()` cancels this handler when a newer
    /// reload arrives; `Task.isCancelled` (Dart `emit.isDone`) is how it notices.
    private func onResultsReloaded(_ date: DateTime?) async {
        if let date { applyActiveDate(date) }
        emit(state.copyWith(isLoading: true))
        try? await Task.sleep(for: Self.reloadDelay)
        if Task.isCancelled { return } // superseded by a newer reload
        await loadResults()
        if Task.isCancelled { return }
        requestDailyMinPrices()
    }

    private func onActiveDateSelected(_ date: DateTime) async {
        applyActiveDate(date)
        await loadResults()
    }

    private func applyActiveDate(_ date: DateTime) {
        setSearchDate(date, isReturn: state.isPickingReturn)
    }

    /// Fetches trips for the active leg, then sorts and filters them.
    private func loadResults(stage: BookingStage? = nil) async {
        let searchReturnDate = state.searchReturnDate
        let result: AppResult<[TripOptionModel]>
        if state.mode == .flight {
            result = await submitFlightSearch(
                FlightSearchRequest(
                    from: state.searchFrom.code,
                    to: state.searchTo.code,
                    departDate: Self.dateOnly(state.activeDate),
                    returnDate: searchReturnDate.map { Self.dateOnly($0) },
                    adults: state.travellerCount,
                    children: state.childCount,
                    infants: state.infantCount,
                    cabin: state.searchCabin.label,
                    nationality: state.nationality.code
                )
            )
        } else {
            result = await searchTrips((
                mode: state.mode,
                date: state.activeDate,
                from: state.searchFrom,
                to: state.searchTo
            ))
        }
        if Task.isCancelled { return }

        switch result {
        case .failure:
            emit(
                state.copyWith(
                    isLoading: false,
                    results: [],
                    availableAirlines: [],
                    availableAirlineLogoUrls: [:],
                    availableAirlineCodes: [:],
                    priceCeiling: 0
                )
            )
        case .success(let trips):
            var logoUrls: [String: String] = [:]
            var codes: [String: String] = [:]
            for trip in trips {
                let name = trip.operatorName.trimmingCharacters(in: .whitespacesAndNewlines)
                let logo = trip.operatorLogoUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty && !logo.isEmpty { logoUrls[name] = logo }
                let code = trip.carrierCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !name.isEmpty && !code.isEmpty { codes[name] = code }
            }
            emit(
                state.copyWith(
                    stage: stage ?? state.stage,
                    isLoading: false,
                    results: sortAndFilter(trips),
                    availableAirlines: Set(
                        trips
                            .map { $0.operatorName.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                    ),
                    availableAirlineLogoUrls: logoUrls,
                    availableAirlineCodes: codes,
                    // Measured on the unfiltered response, so the filter sheet's slider
                    // keeps its full range no matter how narrow the visible list gets.
                    priceCeiling: trips.isEmpty
                        ? 0
                        : trips.map(\.price).reduce(trips[0].price) { a, b in a > b ? a : b }
                )
            )
        }
    }

    /// Fire-and-forget: the date strip renders without prices and fills them in
    /// when they arrive. A bloc may only emit from inside a handler, so this
    /// goes through its own (bloc-only) event rather than a dangling task.
    private func requestDailyMinPrices() {
        if !isClosed { add(.dailyMinPricesRequested) }
    }

    private func onDailyMinPricesRequested() async {
        let result = await getDailyMinPrices(
            GetDailyMinPricesParams(
                mode: state.mode,
                from: state.searchFrom,
                to: state.searchTo,
                around: state.activeDate
            )
        )
        if Task.isCancelled { return }
        if case .success(let prices) = result {
            emit(state.copyWith(dailyMinPrices: prices))
        }
    }

    // MARK: - Sorting / filtering

    private func onSortOrderChanged(_ ascending: Bool) {
        emit(
            state.copyWith(
                results: sortAndFilter(state.results, sortByPriceAsc: ascending),
                sortByPriceAsc: ascending
            )
        )
    }

    /// Applies the filter sheet's selection and reloads.
    ///
    /// Raises `FlightBookingState.isLoading` for the duration, so the results
    /// screen shows its skeleton while the refreshed list is fetched instead of
    /// sitting on stale rows with no sign anything is happening.
    private func onFiltersApplied(
        maxStops: Int?,
        classFilter: TravelClass?,
        maxPrice: Double?,
        airlines: Set<String>?,
        departureTimes: Set<String>?
    ) async {
        emit(
            state.copyWith(
                isLoading: true,
                maxStops: maxStops,
                classFilter: classFilter,
                maxPrice: maxPrice,
                airlineFilter: airlines,
                departureTimeFilter: departureTimes,
                clearFilters: true
            )
        )
        // Re-run the search so filters apply to the full result set, not to what
        // an earlier filter already narrowed down.
        await loadResults()
    }

    private func sortAndFilter(_ trips: [TripOptionModel], sortByPriceAsc: Bool? = nil) -> [TripOptionModel] {
        let ascending = sortByPriceAsc ?? state.sortByPriceAsc
        var list = trips

        if let maxStops = state.maxStops {
            list = list.filter { $0.stops == maxStops }
        }
        if let classFilter = state.classFilter {
            list = list.filter { $0.travelClass == classFilter }
        }
        if let maxPrice = state.maxPrice {
            list = list.filter { $0.price <= maxPrice }
        }
        if let airlines = state.airlineFilter, !airlines.isEmpty {
            list = list.filter { airlines.contains($0.operatorName) }
        }
        if let times = state.departureTimeFilter, !times.isEmpty {
            list = list.filter { times.contains(Self.timeBucket($0.departure)) }
        }

        list.sort { a, b in ascending ? a.price < b.price : b.price < a.price }
        return list
    }

    /// Bucket a departure time falls into — matches the filter sheet's chips.
    static func timeBucket(_ dt: DateTime) -> String {
        let h = dt.hour
        if h >= 6 && h < 12 { return "morning" }
        if h >= 12 && h < 18 { return "afternoon" }
        if h >= 18 { return "evening" }
        return "night"
    }

    // MARK: - Selection & checkout

    /// Preserves the catalogue's route, flight number, fare and next operating
    /// date without making the customer repeat a flight search.
    private func onCommercialFlightEnquiryStarted(_ option: TripOptionModel) {
        emit(
            state.copyWith(
                mode: .flight,
                tripType: .oneWay,
                departDate: option.departure,
                fromLocation: LocationModel(
                    code: option.originCode,
                    city: option.originName,
                    facilityName: option.originName,
                    country: "",
                    searchCode: option.originCode
                ),
                toLocation: LocationModel(
                    code: option.destinationCode,
                    city: option.destinationName,
                    facilityName: option.destinationName,
                    country: "",
                    searchCode: option.destinationCode
                ),
                isFromLocationSelected: true,
                isToLocationSelected: true,
                travellerCount: 1,
                childCount: 0,
                infantCount: 0,
                stage: .detail,
                isLoading: false,
                results: [option],
                selectedOutbound: option,
                maxStops: nil,
                classFilter: nil,
                maxPrice: nil,
                airlineFilter: nil,
                departureTimeFilter: nil,
                dailyMinPrices: [:],
                clearReturnDate: true,
                clearInbound: true,
                clearHoldRequest: true,
                clearHoldResponse: true,
                clearFilters: true
            )
        )
    }

    private func onOutboundSelectionRestarted() async {
        emit(
            state.copyWith(
                clearOutbound: true,
                clearInbound: true,
                clearHoldRequest: true,
                clearHoldResponse: true
            )
        )
        await loadResults(stage: .detail)
    }

    // Backing out of checkout returns to the trip detail page for the *same*
    // selection — that page is still on the stack and reads
    // `FlightBookingState.selectedOutbound`, so the picked legs must survive the
    // pop. Choosing a different flight happens one step further back, in the
    // results list (see `outboundSelectionRestarted`).

    /// Rebuilds the checkout state for a held booking so the payment screen can
    /// pick it up where it was left.
    ///
    /// Everything the payment screen reads is set in one go: the itinerary it
    /// renders, the reservation it confirms against, and the contact details it
    /// submits.
    private func onHeldBookingResumed(
        from: LocationModel,
        to: LocationModel,
        departDate: DateTime,
        adults: Int,
        children: Int,
        infants: Int,
        cabinClass: TravelClass,
        outbound: TripOptionModel,
        inbound: TripOptionModel?,
        holdRequest: FlightHoldRequest,
        holdResponse: FlightHoldResponse,
        stage: BookingStage
    ) {
        emit(
            state.copyWith(
                mode: .flight,
                tripType: inbound == nil ? .oneWay : .roundTrip,
                departDate: departDate,
                returnDate: inbound?.departure,
                fromLocation: from,
                toLocation: to,
                isFromLocationSelected: true,
                isToLocationSelected: true,
                travellerCount: adults,
                childCount: children,
                infantCount: infants,
                cabinClass: cabinClass,
                stage: stage,
                isLoading: false,
                selectedOutbound: outbound,
                selectedInbound: inbound,
                holdRequest: holdRequest,
                holdResponse: holdResponse,
                clearReturnDate: inbound == nil
            )
        )
    }

    private func onBookingReset() {
        emit(
            state.copyWith(
                travellerCount: 1,
                childCount: 0,
                infantCount: 0,
                stage: .search,
                results: [],
                availableAirlines: [],
                availableAirlineLogoUrls: [:],
                availableAirlineCodes: [:],
                clearOutbound: true,
                clearInbound: true,
                clearHoldRequest: true,
                clearHoldResponse: true,
                clearFilters: true
            )
        )
    }
}
