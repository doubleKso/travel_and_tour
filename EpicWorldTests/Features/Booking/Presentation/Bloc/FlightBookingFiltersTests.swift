import XCTest
@testable import EpicWorld

/// Port of test/features/booking/presentation/bloc/flight_booking_filters_test.dart.
final class FlightBookingFiltersTests: XCTestCase {
    private func flight(
        _ id: String,
        operatorName: String = "MAI Airway",
        travelClass: TravelClass = .economy,
        price: Double = 100000,
        stops: Int = 0
    ) -> TripOptionModel {
        TripOptionModel(
            id: id,
            mode: .flight,
            operatorName: operatorName,
            operatorLogoUrl: "",
            originCode: "RGN",
            originName: "Yangon",
            destinationCode: "MDL",
            destinationName: "Mandalay",
            departure: DateTime(2026, 9, 1, 8),
            arrival: DateTime(2026, 9, 1, 9),
            stops: stops,
            travelClass: travelClass,
            price: price,
            currency: "MMK"
        )
    }

    /// `setUp` + `tearDown(() => bloc.close())`.
    @MainActor
    private func makeBloc() -> (FlightBookingBloc, FakeRepo) {
        let repository = FakeRepo()
        let bloc = flightBookingBlocFor(repository)
        addTeardownBlock { await bloc.close() }
        return (bloc, repository)
    }

    // MARK: - cabin class carries into the results list

    @MainActor
    func testSearchingAfterPickingBusinessFiltersOutEconomy() async {
        let (bloc, repository) = makeBloc()
        repository.flightResults = [
            flight("eco", price: 100000),
            flight("biz", travelClass: .business, price: 300000),
        ]

        await bloc.dispatch(.cabinClassChanged(.business))
        await bloc.dispatch(.flightSearchRequested)

        XCTAssertEqual(bloc.state.classFilter, .business)
        XCTAssertEqual(bloc.state.results.count, 1)
        XCTAssertEqual(bloc.state.results.first?.travelClass, .business)
    }

    @MainActor
    func testEconomyIsStillTheDefaultWhenNothingIsPicked() async {
        let (bloc, repository) = makeBloc()
        repository.flightResults = [
            flight("eco"),
            flight("biz", travelClass: .business),
        ]

        await bloc.dispatch(.flightSearchRequested)

        XCTAssertEqual(bloc.state.classFilter, .economy)
        XCTAssertEqual(bloc.state.results.count, 1)
        XCTAssertEqual(bloc.state.results.first?.travelClass, .economy)
    }

    @MainActor
    func testClearingTheClassFilterWidensBackToEveryClass() async {
        let (bloc, repository) = makeBloc()
        repository.flightResults = [
            flight("eco"),
            flight("biz", travelClass: .business),
        ]
        await bloc.dispatch(.cabinClassChanged(.business))
        await bloc.dispatch(.flightSearchRequested)

        await bloc.dispatch(.filtersApplied())

        XCTAssertNil(bloc.state.classFilter)
        XCTAssertEqual(bloc.state.results.count, 2)
    }

    // MARK: - FiltersApplied reports progress

    @MainActor
    func testRaisesIsLoadingWhileReloadingLowersItWhenDone() async {
        let (bloc, repository) = makeBloc()
        repository.flightResults = [flight("a")]
        await bloc.dispatch(.flightSearchRequested)

        let recorder = StateRecorder(bloc)
        bloc.add(.filtersApplied(maxPrice: 50000))
        await bloc.settle()
        recorder.cancel()

        XCTAssertEqual(recorder.states.map(\.isLoading), [true, false])
    }

    // MARK: - cabin reaches the searchFlights request

    @MainActor
    func testABusinessSearchAsksTheServiceForBusiness() async {
        let (bloc, repository) = makeBloc()
        repository.flightResults = [
            flight("biz", travelClass: .business, price: 300000),
        ]

        await bloc.dispatch(.cabinClassChanged(.business))
        await bloc.dispatch(.flightSearchRequested)

        XCTAssertEqual(repository.requests.last?.cabin, "Business")
        XCTAssertEqual(bloc.state.results.count, 1)
    }

    @MainActor
    func testEconomyIsRequestedByDefault() async {
        let (bloc, repository) = makeBloc()
        repository.flightResults = [flight("eco")]
        await bloc.dispatch(.flightSearchRequested)

        XCTAssertEqual(repository.requests.last?.cabin, "Economy")
    }

    @MainActor
    func testSwitchingClassInTheFilterSheetReRequestsThatCabin() async {
        let (bloc, repository) = makeBloc()
        repository.flightResults = [flight("eco")]
        await bloc.dispatch(.cabinClassChanged(.business))
        await bloc.dispatch(.flightSearchRequested)
        XCTAssertEqual(repository.requests.last?.cabin, "Business")

        // Narrowing to Economy has to change the request too — filtering an
        // all-Business response for Economy would just empty the list.
        await bloc.dispatch(.filtersApplied(classFilter: .economy))

        XCTAssertEqual(repository.requests.last?.cabin, "Economy")
        XCTAssertEqual(bloc.state.results.count, 1)
    }

    @MainActor
    func testAnyFallsBackToTheCabinPickedOnTheSearchForm() async {
        let (bloc, repository) = makeBloc()
        repository.flightResults = [
            flight("biz", travelClass: .business),
        ]
        await bloc.dispatch(.cabinClassChanged(.business))
        await bloc.dispatch(.flightSearchRequested)

        await bloc.dispatch(.filtersApplied())

        XCTAssertNil(bloc.state.classFilter)
        XCTAssertEqual(repository.requests.last?.cabin, "Business")
    }

    // MARK: - nationality reaches the searchFlights request

    @MainActor
    func testMyanmarIsRequestedByDefault() async {
        let (bloc, repository) = makeBloc()
        await bloc.dispatch(.flightSearchRequested)

        XCTAssertEqual(repository.requests.last?.nationality, "MM")
    }

    @MainActor
    func testPickingOtherChangesWhatTheServiceIsAskedFor() async {
        let (bloc, repository) = makeBloc()
        await bloc.dispatch(.nationalityChanged(.foreigner))
        await bloc.dispatch(.flightSearchRequested)

        XCTAssertEqual(repository.requests.last?.nationality, "OTHER")
    }

    // MARK: - return date on the searchFlights request

    @MainActor
    func testAOneWaySearchSendsNoneDespiteTheFormDefault() async {
        let (bloc, repository) = makeBloc()
        XCTAssertNotNil(bloc.state.returnDate)

        await bloc.dispatch(.flightSearchRequested)

        XCTAssertNotNil(repository.requests.last)
        XCTAssertNil(repository.requests.last?.returnDate)
    }

    @MainActor
    func testARoundTripOutboundSearchSendsTheReturnDate() async {
        let (bloc, repository) = makeBloc()
        await bloc.dispatch(.tripTypeChanged(.roundTrip))
        await bloc.dispatch(.departDateChanged(DateTime(2026, 11, 15)))
        await bloc.dispatch(.returnDateChanged(DateTime(2026, 11, 20)))

        await bloc.dispatch(.flightSearchRequested)

        XCTAssertEqual(repository.requests.last?.departDate, "2026-11-15")
        XCTAssertEqual(repository.requests.last?.returnDate, "2026-11-20")
    }

    @MainActor
    func testTheReturnLegIsSearchedOnItsOwnWithoutOne() async {
        let (bloc, repository) = makeBloc()
        await bloc.dispatch(.tripTypeChanged(.roundTrip))
        await bloc.dispatch(.departDateChanged(DateTime(2026, 11, 15)))
        await bloc.dispatch(.returnDateChanged(DateTime(2026, 11, 20)))
        await bloc.dispatch(.flightSearchRequested)

        await bloc.dispatch(.outboundSelected(flight("out")))
        await bloc.dispatch(.resultsRefreshed)

        let request = repository.requests.last
        XCTAssertEqual(request?.departDate, "2026-11-20")
        XCTAssertNotNil(request)
        XCTAssertNil(request?.returnDate)
    }

    // MARK: - price filter

    @MainActor
    func testDropsFaresAboveTheCeiling() async {
        let (bloc, repository) = makeBloc()
        repository.flightResults = [
            flight("cheap", price: 100000),
            flight("dear", price: 300000),
        ]
        await bloc.dispatch(.flightSearchRequested)

        await bloc.dispatch(.filtersApplied(maxPrice: 150000))

        XCTAssertEqual(bloc.state.results.map(\.price), [100000.0])
    }

    @MainActor
    func testCeilingTracksTheUnfilteredResponseNotTheVisibleRows() async {
        let (bloc, repository) = makeBloc()
        repository.flightResults = [
            flight("cheap", price: 100000),
            flight("dear", price: 300000),
        ]
        await bloc.dispatch(.flightSearchRequested)
        XCTAssertEqual(bloc.state.priceCeiling, 300000)

        // Narrowing the list must not shrink the ceiling the slider is built
        // from, or the filter cannot be widened again afterwards.
        await bloc.dispatch(.filtersApplied(maxPrice: 150000))

        XCTAssertEqual(bloc.state.results.count, 1)
        XCTAssertEqual(bloc.state.priceCeiling, 300000)
    }

    @MainActor
    func testAPriceFilterCanBeRelaxedAfterBeingApplied() async {
        let (bloc, repository) = makeBloc()
        repository.flightResults = [
            flight("cheap", price: 100000),
            flight("dear", price: 300000),
        ]
        await bloc.dispatch(.flightSearchRequested)
        await bloc.dispatch(.filtersApplied(maxPrice: 150000))

        await bloc.dispatch(.filtersApplied(maxPrice: 320000))

        XCTAssertEqual(bloc.state.results.count, 2)
    }

    // MARK: - price sorting

    @MainActor
    func testCheapestAndHighestOrderAllAirlinesByPrice() async {
        let (bloc, repository) = makeBloc()
        repository.flightResults = [
            flight("mna", operatorName: "Myanmar National Airlines", price: 300000),
            flight("mai", price: 100000),
            flight("kbz", operatorName: "Air KBZ", price: 200000),
        ]
        await bloc.dispatch(.flightSearchRequested)

        XCTAssertEqual(bloc.state.results.map(\.id), ["mai", "kbz", "mna"])

        await bloc.dispatch(.sortOrderChanged(ascending: false))

        XCTAssertEqual(bloc.state.results.map(\.id), ["mna", "kbz", "mai"])
    }

    // MARK: - stops filter

    @MainActor
    func testMatchesTheSelectedNumberOfStopsAndAnyRestoresAll() async {
        let (bloc, repository) = makeBloc()
        repository.flightResults = [
            flight("direct"),
            flight("one-stop", stops: 1),
            flight("two-stops", stops: 2),
        ]
        await bloc.dispatch(.flightSearchRequested)

        await bloc.dispatch(.filtersApplied(maxStops: 0))
        XCTAssertEqual(bloc.state.results.map(\.id), ["direct"])

        await bloc.dispatch(.filtersApplied(maxStops: 1))
        XCTAssertEqual(bloc.state.results.map(\.id), ["one-stop"])

        await bloc.dispatch(.filtersApplied())
        XCTAssertEqual(bloc.state.results.count, 3)
    }
}

// MARK: - Helpers (test/helpers/notifiers.dart)

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

/// Collects every state the bloc emits (`expectLater(bloc.stream…)`).
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

private final class FakeRepo: BookingRepository {
    var flightResults: [TripOptionModel] = []

    /// Cabin values seen by the service, newest last.
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
        .success(flightResults)
    }

    func submitFlightSearch(_ request: FlightSearchRequest) async -> AppResult<[TripOptionModel]> {
        requests.append(request)
        return .success(flightResults)
    }
}
