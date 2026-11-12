// Port of test/features/ticket/domain/entities/resume_held_booking_test.dart
import XCTest
@testable import EpicWorld

private func heldBooking(tripType: String = "one-way") -> BookingHistoryItem {
    BookingHistoryItem.fromJson([
        "id": "2b06fb0c-41b0-4103-bb44-3ed268bca987",
        "reference": "EW-SUK2R7",
        "pnr": "17RHFC",
        "status": "held",
        "route": "RGN → SIN",
        "cabin": "economy",
        "currency": "MMK",
        "total": 303,
        "perPaxFare": 505818,
        "adults": 1,
        "children": 0,
        "infants": 0,
        "mode": "flight",
        "tripType": tripType,
        "contactFullName": "Zeck Dhwye",
        "contactEmail": "sjbudv0wrv@gmail.com",
        "contactPhone": "9259807040",
        "contactTitle": "Mr",
        "contactCountryCode": "+95",
        "createdAt": "2026-08-31T09:17:32.331587Z",
        "ticketTimeLimit": "2026-09-01T09:17:30.000000Z",
    ])
}

/// The Dart test hands the bloc a fake `BookingRepository` whose calls answer
/// at once. Here the bloc is built the way the app builds it, over a fake
/// transport: no callable ever reaches the network, so nothing these tests
/// assert on can depend on one.
private final class OfflineCallable: CallableInvoking {
    func call(_ url: String, _ data: Any?, timeout: TimeInterval?) async throws -> Any? {
        throw FunctionsException(code: "unavailable", message: "Offline in tests.")
    }
}

final class ResumeHeldBookingTests: XCTestCase {
    /// `flightBookingBlocFor(_FakeRepo())`, plus the container keeping its
    /// dependencies alive.
    @MainActor
    private func makeBloc() -> (container: AppContainer, bloc: FlightBookingBloc) {
        let container = AppContainer()
        container.override("functions", with: OfflineCallable() as CallableInvoking)
        return (container, container.flightBookingBloc)
    }

    /// `bloc.dispatch(event)`: add, then let the queue drain.
    @MainActor
    private func dispatch(_ bloc: FlightBookingBloc, _ event: FlightBookingEvent) async {
        bloc.add(event)
        for _ in 0..<20 { await Task.yield() }
    }

    @MainActor
    private func resume(_ bloc: FlightBookingBloc, _ r: HeldBookingResume) async {
        await dispatch(bloc, .heldBookingResumed(
            from: r.from,
            to: r.to,
            departDate: r.departDate,
            adults: r.adults,
            children: r.children,
            infants: r.infants,
            cabinClass: r.cabinClass,
            outbound: r.outbound,
            inbound: r.inbound,
            holdRequest: r.holdRequest,
            holdResponse: r.holdResponse,
            stage: .payment
        ))
    }

    @MainActor
    func testResumingLeavesThePaymentScreenEverythingItNeeds() async {
        let (container, bloc) = makeBloc()
        await resume(bloc, HeldBookingResume.from(heldBooking()))
        let state = bloc.state

        // Without a selected flight the payment screen renders an empty page, and
        // without both hold halves it refuses to take payment at all.
        XCTAssertNotNil(state.selectedOutbound)
        XCTAssertNotNil(state.holdRequest)
        XCTAssertNotNil(state.holdResponse)
        XCTAssertEqual(state.stage, BookingStage.payment)
        XCTAssertNotNil(container)
    }

    @MainActor
    func testTheAmountOwedSurvivesNotThePrePromoFare() async {
        let (container, bloc) = makeBloc()
        await resume(bloc, HeldBookingResume.from(heldBooking()))

        XCTAssertEqual(bloc.state.holdResponse?.total, 303)
        XCTAssertEqual(bloc.state.holdResponse?.reference, "EW-SUK2R7")
        XCTAssertEqual(bloc.state.holdRequest?.contact["email"] as? String, "sjbudv0wrv@gmail.com")
        XCTAssertNotNil(container)
    }

    @MainActor
    func testRouteTravellersAndCabinComeBack() async {
        let (container, bloc) = makeBloc()
        await resume(bloc, HeldBookingResume.from(heldBooking()))
        let state = bloc.state

        XCTAssertEqual(state.fromLocation.code, "RGN")
        XCTAssertEqual(state.toLocation.code, "SIN")
        XCTAssertEqual(state.totalTravellers, 1)
        XCTAssertEqual(state.cabinClass, TravelClass.economy)
        XCTAssertNotNil(container)
    }

    @MainActor
    func testAOneWayHoldDoesNotComeBackAsARoundTrip() async {
        let (container, bloc) = makeBloc()
        await resume(bloc, HeldBookingResume.from(heldBooking()))

        XCTAssertEqual(bloc.state.tripType, TripType.oneWay)
        XCTAssertNil(bloc.state.selectedInbound)
        XCTAssertNil(bloc.state.returnDate)
        XCTAssertNotNil(container)
    }

    @MainActor
    func testAnEarlierRoundTripDoesNotLeakIntoAOneWayResume() async {
        let (container, bloc) = makeBloc()
        // A stale return leg left over from a previous search would otherwise make
        // the payment screen ask for a second flight that is not part of this hold.
        await dispatch(bloc, .tripTypeChanged(.roundTrip))
        await dispatch(bloc, .returnDateChanged(DateTime(2026, 12, 1)))

        await resume(bloc, HeldBookingResume.from(heldBooking()))

        XCTAssertEqual(bloc.state.tripType, TripType.oneWay)
        XCTAssertNil(bloc.state.returnDate)
        XCTAssertNil(bloc.state.selectedInbound)
        XCTAssertNotNil(container)
    }
}
