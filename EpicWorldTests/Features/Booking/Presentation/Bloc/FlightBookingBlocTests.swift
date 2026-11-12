import XCTest
@testable import EpicWorld

/// Port of test/features/booking/presentation/bloc/flight_booking_bloc_test.dart
/// (including its `blocTest` cases).
final class FlightBookingBlocTests: XCTestCase {
    private func flight(
        _ id: String,
        operatorName: String = "MAI Airway",
        operatorLogoUrl: String = "",
        carrierCode: String? = nil,
        bookable: Bool? = nil
    ) -> TripOptionModel {
        TripOptionModel(
            id: id,
            mode: .flight,
            operatorName: operatorName,
            operatorLogoUrl: operatorLogoUrl,
            carrierCode: carrierCode,
            originCode: "RGN",
            originName: "Yangon",
            destinationCode: "MDL",
            destinationName: "Mandalay",
            departure: DateTime(2026, 9, 1, 8),
            arrival: DateTime(2026, 9, 1, 9),
            stops: 0,
            travelClass: .economy,
            price: 100000,
            currency: "MMK",
            bookable: bookable
        )
    }

    /// `setUp` + `tearDown(() => bloc.close())`.
    @MainActor
    private func makeBloc() -> (FlightBookingBloc, FakeBookingRepository) {
        let repository = FakeBookingRepository()
        let bloc = flightBookingBlocFor(repository)
        addTeardownBlock { await bloc.close() }
        return (bloc, repository)
    }

    @MainActor
    func testHomeStartsAtRgnWhileDestinationStaysUnselected() async {
        let (bloc, _) = makeBloc()

        XCTAssertFalse(bloc.state.hasCompleteRoute)
        XCTAssertEqual(bloc.state.fromLocation.code, "RGN")
        XCTAssertEqual(bloc.state.fromLocation.facilityName, "Yangon International Airport")
        XCTAssertTrue(bloc.state.isFromLocationSelected)
        XCTAssertFalse(bloc.state.isToLocationSelected)

        await bloc.dispatch(.toLocationChanged(LocationModel.defaultDestination))
        XCTAssertTrue(bloc.state.hasCompleteRoute)
    }

    @MainActor
    func testHomeKeepsTodayAsTheDefaultDateForEitherRoundTripLeg() async {
        let (bloc, _) = makeBloc()
        let now = DateTime.now()
        let today = DateTime(now.year, now.month, now.day)

        XCTAssertEqual(bloc.state.departDate, today)

        await bloc.dispatch(.tripTypeChanged(.roundTrip))
        XCTAssertEqual(bloc.state.departDate, today)
        XCTAssertEqual(bloc.state.returnDate, today)

        await bloc.dispatch(.tripTypeChanged(.oneWay))
        XCTAssertEqual(bloc.state.departDate, today)

        await bloc.dispatch(.tripTypeChanged(.roundTrip))
        XCTAssertEqual(bloc.state.returnDate, today)
    }

    @MainActor
    func testChangingTheDepartureDateClearsBothRoundTripSelections() async {
        let (bloc, _) = makeBloc()
        await bloc.dispatch(.tripTypeChanged(.roundTrip))
        await bloc.dispatch(.departDateChanged(DateTime(2026, 9, 1)))
        await bloc.dispatch(.returnDateChanged(DateTime(2026, 9, 8)))
        await bloc.dispatch(.outboundSelected(flight("outbound")))
        await bloc.dispatch(.inboundSelected(flight("inbound")))

        await bloc.dispatch(.departDateChanged(DateTime(2026, 9, 2)))

        XCTAssertNil(bloc.state.selectedOutbound)
        XCTAssertNil(bloc.state.selectedInbound)
        XCTAssertTrue(bloc.state.needsReturnSelection)
    }

    @MainActor
    func testChangingTheReturnDateClearsBothRoundTripSelections() async {
        let (bloc, _) = makeBloc()
        await bloc.dispatch(.tripTypeChanged(.roundTrip))
        await bloc.dispatch(.departDateChanged(DateTime(2026, 9, 1)))
        await bloc.dispatch(.returnDateChanged(DateTime(2026, 9, 8)))
        await bloc.dispatch(.outboundSelected(flight("outbound")))
        await bloc.dispatch(.inboundSelected(flight("inbound")))

        await bloc.dispatch(.returnDateChanged(DateTime(2026, 9, 9)))

        XCTAssertNil(bloc.state.selectedOutbound)
        XCTAssertNil(bloc.state.selectedInbound)
        XCTAssertTrue(bloc.state.needsReturnSelection)
    }

    @MainActor
    func testAFreshHomeSearchClearsFlightsSelectedOnAnEarlierVisit() async {
        let (bloc, repository) = makeBloc()
        repository.flightResults = [flight("same-route-flight")]
        await bloc.dispatch(.outboundSelected(flight("same-route-flight")))
        await bloc.dispatch(.inboundSelected(flight("old-return-flight")))

        var emissions = bloc.stream.makeAsyncIterator()
        bloc.add(.flightSearchRequested)

        // Clearing happens in the first emission, before the network request
        // completes, so even a result with the same ID cannot render as
        // selected during the new search.
        let loading = await emissions.next()
        XCTAssertEqual(loading?.isLoading, true)
        XCTAssertNil(loading?.selectedOutbound)
        XCTAssertNil(loading?.selectedInbound)
        await bloc.settle()
        XCTAssertFalse(bloc.state.isLoading)
        XCTAssertNil(bloc.state.selectedOutbound)
        XCTAssertNil(bloc.state.selectedInbound)
    }

    @MainActor
    func testReturnDateCanMatchDepartureButCannotPrecedeIt() async {
        let (bloc, _) = makeBloc()
        await bloc.dispatch(.tripTypeChanged(.roundTrip))
        await bloc.dispatch(.departDateChanged(DateTime(2026, 8, 29)))
        await bloc.dispatch(.returnDateChanged(DateTime(2026, 9, 5)))

        await bloc.dispatch(.returnDateChanged(DateTime(2026, 8, 29)))
        XCTAssertEqual(bloc.state.returnDate, DateTime(2026, 8, 29))

        await bloc.dispatch(.returnDateChanged(DateTime(2026, 8, 28)))
        XCTAssertEqual(bloc.state.returnDate, DateTime(2026, 8, 29))
    }

    @MainActor
    func testMovingDepartureOntoTheReturnDateKeepsASameDayReturn() async {
        let (bloc, _) = makeBloc()
        await bloc.dispatch(.tripTypeChanged(.roundTrip))
        await bloc.dispatch(.departDateChanged(DateTime(2026, 8, 29)))
        await bloc.dispatch(.returnDateChanged(DateTime(2026, 9, 1)))

        await bloc.dispatch(.departDateChanged(DateTime(2026, 9, 1, 15)))

        XCTAssertEqual(bloc.state.departDate, DateTime(2026, 9, 1, 15))
        XCTAssertEqual(bloc.state.returnDate, DateTime(2026, 9, 1))
    }

    @MainActor
    func testAdultsChildrenAndInfantsTogetherNeverPassNine() async {
        let (bloc, _) = makeBloc()
        // Each category on its own used to allow nine, i.e. 27 in total.
        await bloc.dispatch(.adultCountChanged(20))
        XCTAssertEqual(bloc.state.travellerCount, 9)
        XCTAssertEqual(bloc.state.maxChildren, 0)
        await bloc.dispatch(.childCountChanged(1))
        XCTAssertEqual(bloc.state.childCount, 0)

        await bloc.dispatch(.adultCountChanged(4))
        await bloc.dispatch(.childCountChanged(20))
        XCTAssertEqual(bloc.state.childCount, 5)
        XCTAssertEqual(bloc.state.totalTravellers, 9)

        // Infants still ride on a lap: capped by the adults and the seats left.
        await bloc.dispatch(.childCountChanged(1))
        await bloc.dispatch(.infantCountChanged(20))
        XCTAssertEqual(bloc.state.infantCount, 4)
        XCTAssertEqual(bloc.state.totalTravellers, 9)
        XCTAssertEqual(bloc.state.maxAdults, 4)
        await bloc.dispatch(.adultCountChanged(5))
        XCTAssertEqual(bloc.state.travellerCount, 4)

        // Fewer adults drags the lap infants down with them.
        await bloc.dispatch(.adultCountChanged(2))
        XCTAssertEqual(bloc.state.infantCount, 2)
        XCTAssertEqual(bloc.state.totalTravellers, 5)
    }

    @MainActor
    func testACommercialScheduleStartsAPrefilledEnquiryFlow() async {
        let (bloc, _) = makeBloc()
        let commercialFlight = flight(
            "schedule-mna-rgn-mdl",
            operatorName: "Myanmar National Airlines",
            carrierCode: "MNA",
            bookable: false
        )

        await bloc.dispatch(.commercialFlightEnquiryStarted(commercialFlight))

        XCTAssertEqual(bloc.state.stage, .detail)
        XCTAssertEqual(bloc.state.tripType, .oneWay)
        // Dart `same(commercialFlight)`: the selected leg is that very option.
        XCTAssertEqual(bloc.state.selectedOutbound, commercialFlight)
        XCTAssertNil(bloc.state.selectedInbound)
        XCTAssertFalse(bloc.state.isBookableSelected)
        XCTAssertEqual(bloc.state.fromLocation.code, "RGN")
        XCTAssertEqual(bloc.state.toLocation.code, "MDL")
        XCTAssertTrue(bloc.state.hasCompleteRoute)
    }

    @MainActor
    func testAirlineChoicesSurviveFilteringTheVisibleResults() async {
        let (bloc, repository) = makeBloc()
        repository.flightResults = [
            flight("mai"),
            flight(
                "kbz",
                operatorName: "Air KBZ",
                operatorLogoUrl: "https://example.com/k7.png",
                carrierCode: "K7"
            ),
        ]

        await bloc.dispatch(.flightSearchRequested)
        XCTAssertEqual(bloc.state.availableAirlines, ["MAI Airway", "Air KBZ"])
        XCTAssertEqual(bloc.state.availableAirlineCodes["Air KBZ"], "K7")
        XCTAssertEqual(bloc.state.availableAirlineLogoUrls["Air KBZ"], "https://example.com/k7.png")

        await bloc.dispatch(.filtersApplied(airlines: ["MAI Airway"]))
        await bloc.dispatch(.resultsRefreshed)

        XCTAssertEqual(bloc.state.results.count, 1)
        XCTAssertEqual(bloc.state.results.first?.operatorName, "MAI Airway")
        XCTAssertEqual(bloc.state.availableAirlines, ["MAI Airway", "Air KBZ"])
        XCTAssertEqual(bloc.state.availableAirlineCodes["Air KBZ"], "K7")
        XCTAssertEqual(bloc.state.availableAirlineLogoUrls["Air KBZ"], "https://example.com/k7.png")
    }

    // MARK: - event handling
    //
    // What only a bloc can be asked: the exact sequence of states an event
    // produces, and how overlapping events are handled.

    /// blocTest: 'a search emits the skeleton, the results, then the date-strip prices'.
    @MainActor
    func testASearchEmitsTheSkeletonTheResultsThenTheDateStripPrices() async {
        let (bloc, repository) = makeBloc()
        repository.flightResults = [flight("mai")]
        let recorder = StateRecorder(bloc)

        bloc.add(.flightSearchRequested)
        await bloc.settle()
        recorder.cancel()

        let states = recorder.states
        XCTAssertEqual(states.count, 3)
        guard states.count == 3 else { return }
        XCTAssertTrue(states[0].isLoading)
        XCTAssertTrue(states[0].results.isEmpty)
        XCTAssertFalse(states[1].isLoading)
        XCTAssertEqual(states[1].results.count, 1)
        XCTAssertEqual(states[1].stage, .detail)
        // Fire-and-forget: raised by the bloc itself once results are in.
        XCTAssertTrue(states[2].dailyMinPrices.isEmpty)
        XCTAssertEqual(states[2].results.count, 1)
    }

    /// blocTest: 'a newer reload cancels the one still in its skeleton (restartable)'.
    @MainActor
    func testANewerReloadCancelsTheOneStillInItsSkeleton() async {
        let (bloc, repository) = makeBloc()

        bloc.add(.resultsReloaded(date: DateTime(2026, 9, 1)))
        bloc.add(.resultsReloaded(date: DateTime(2026, 9, 2)))
        // Long enough for one 700 ms skeleton, not for two in a row.
        try? await Task.sleep(for: .milliseconds(1000))
        await bloc.settle()

        // Only the newer date ever reached the service; the first reload was
        // dropped during its delay instead of landing stale results later.
        XCTAssertEqual(repository.requests.map(\.departDate), ["2026-09-02"])
        XCTAssertEqual(bloc.state.departDate, DateTime(2026, 9, 2))
        XCTAssertFalse(bloc.state.isLoading)
    }
}

// MARK: - Helpers (test/helpers/notifiers.dart)

/// `flightBookingBlocFor(repository)`: the bloc exactly as
/// `container.flightBookingBloc` builds it, over a fake repository.
@MainActor
private func flightBookingBlocFor(_ repository: BookingRepository) -> FlightBookingBloc {
    FlightBookingBloc(
        submitFlightSearch: SubmitFlightSearchUseCase(repository),
        searchTrips: SearchTripsUseCase(repository),
        getDailyMinPrices: GetDailyMinPricesUseCase(repository)
    )
}

@MainActor
private extension FlightBookingBloc {
    /// Adds `event` and waits for the bloc to finish handling it.
    ///
    /// `add` is asynchronous, so a test that reads `state` straight after it
    /// sees the old value. This lets the event queue drain first — enough for
    /// the synchronous handlers and for a fake repository's immediate answers.
    /// It does not wait out real delays (the 700 ms reload skeleton).
    func dispatch(_ event: FlightBookingEvent) async {
        add(event)
        await settle()
    }

    /// Lets every queued event and task run (Dart's `pumpEventQueue`).
    func settle() async {
        for _ in 0..<20 { await Task.yield() }
        try? await Task.sleep(for: .milliseconds(30))
        for _ in 0..<20 { await Task.yield() }
    }
}

/// Collects every state the bloc emits (`expect: [...]` of `blocTest`).
@MainActor
private final class StateRecorder {
    private(set) var states: [FlightBookingState] = []
    private var task: Task<Void, Never>?

    init(_ bloc: FlightBookingBloc) {
        let stream = bloc.stream
        task = Task { @MainActor [weak self] in
            for await state in stream { self?.states.append(state) }
        }
    }

    func cancel() {
        task?.cancel()
    }
}

private final class FakeBookingRepository: BookingRepository {
    var flightResults: [TripOptionModel] = []

    /// Every search the service was asked for, oldest first.
    private(set) var requests: [FlightSearchRequest] = []

    func createServiceEnquiry(_ request: ServiceEnquiryRequest) async -> AppResult<ServiceEnquirySubmission> {
        .failure(.unexpected(UnimplementedError().description))
    }

    func getDailyMinPrices(
        mode: TravelMode,
        from: LocationModel,
        to: LocationModel,
        around: DateTime,
        windowDays: Int
    ) async -> AppResult<[DateTime: Double]> {
        .success([:])
    }

    func getLocations() async -> AppResult<[LocationModel]> {
        .failure(.unexpected(UnimplementedError().description))
    }

    func getMyServiceEnquiries(userId: String, email: String) async -> AppResult<[ServiceEnquiryModel]> {
        .failure(.unexpected(UnimplementedError().description))
    }

    func holdFlight(_ request: FlightHoldRequest) async -> AppResult<FlightHoldResponse> {
        .failure(.unexpected(UnimplementedError().description))
    }

    func searchTrips(
        mode: TravelMode,
        date: DateTime,
        from: LocationModel,
        to: LocationModel
    ) async -> AppResult<[TripOptionModel]> {
        .failure(.unexpected(UnimplementedError().description))
    }

    func submitFlightSearch(_ request: FlightSearchRequest) async -> AppResult<[TripOptionModel]> {
        requests.append(request)
        return .success(flightResults)
    }
}
