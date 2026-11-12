import XCTest
@testable import EpicWorld

/// Port of test/features/booking/presentation/bloc/flight_booking_state_test.dart.
final class FlightBookingStateTests: XCTestCase {
    private func flight(airline: String, carrierCode: String? = nil) -> TripOptionModel {
        TripOptionModel(
            id: "\(airline)-\(carrierCode ?? "null")",
            mode: .flight,
            operatorName: airline,
            operatorLogoUrl: "",
            carrierCode: carrierCode,
            originCode: "RGN",
            originName: "Yangon",
            destinationCode: "MDL",
            destinationName: "Mandalay",
            departure: DateTime(2026, 8, 25, 8),
            arrival: DateTime(2026, 8, 25, 9),
            stops: 0,
            travelClass: .economy,
            price: 100000,
            currency: "MMK"
        )
    }

    func testMaiCarrierCodeOpensTheInstantBookingFlow() {
        let state = FlightBookingState(
            departDate: DateTime(2026, 8, 25),
            selectedOutbound: flight(airline: "Myanmar Airways International", carrierCode: "8M")
        )

        XCTAssertTrue(state.isBookableSelected)
    }

    func testANonMaiSelectedFlightOpensTheReservationFlow() {
        let state = FlightBookingState(
            departDate: DateTime(2026, 8, 25),
            selectedOutbound: flight(airline: "Air KBZ", carrierCode: "K7")
        )

        XCTAssertFalse(state.isBookableSelected)
    }

    func testAMixedRoundTripOpensTheReservationFlow() {
        let state = FlightBookingState(
            departDate: DateTime(2026, 8, 25),
            selectedOutbound: flight(airline: "MAI Airway", carrierCode: "8M"),
            selectedInbound: flight(airline: "Air KBZ", carrierCode: "K7")
        )

        XCTAssertFalse(state.isBookableSelected)
    }

    func testAppliesTheRequiredNrcAndPassportRulesByScopeAndNationality() {
        let domestic = FlightBookingState(departDate: DateTime(2026, 8, 25))
        // Scope follows the route, so an international case needs a foreign
        // endpoint — the default RGN → MDL pair is domestic whatever the
        // scope toggle is set to.
        let international = FlightBookingState(
            departDate: DateTime(2026, 8, 25),
            scope: .international,
            toLocation: LocationModel(
                code: "BKK",
                city: "Bangkok",
                facilityName: "Suvarnabhumi",
                country: "Thailand"
            )
        )

        XCTAssertTrue(domestic.nrcRequiredFor(travellerIsMyanmar: true, isAdult: true))
        XCTAssertFalse(domestic.nrcRequiredFor(travellerIsMyanmar: true, isAdult: false))
        XCTAssertTrue(domestic.passportRequiredFor(travellerIsMyanmar: false))
        XCTAssertTrue(international.nrcRequiredFor(travellerIsMyanmar: true, isAdult: false))
        XCTAssertTrue(international.passportRequiredFor(travellerIsMyanmar: true))
        XCTAssertFalse(international.nrcRequiredFor(travellerIsMyanmar: false, isAdult: false))
        XCTAssertTrue(international.passportRequiredFor(travellerIsMyanmar: false))
    }
}
