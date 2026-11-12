import XCTest
@testable import EpicWorld

/// Port of test/features/booking/presentation/bloc/traveller_document_rules_test.dart.
final class TravellerDocumentRulesTests: XCTestCase {
    private let ygn = LocationModel(
        code: "RGN",
        city: "Yangon",
        facilityName: "Yangon International Airport",
        country: "Myanmar"
    )
    private let mdy = LocationModel(
        code: "MDL",
        city: "Mandalay",
        facilityName: "Mandalay International Airport",
        country: "Myanmar"
    )
    private let bkk = LocationModel(
        code: "BKK",
        city: "Bangkok",
        facilityName: "Suvarnabhumi",
        country: "Thailand"
    )
    private let unknown = LocationModel(
        code: "XXX",
        city: "Somewhere",
        facilityName: "",
        country: ""
    )

    private func state(
        from: LocationModel,
        to: LocationModel,
        scope: TravelScope = .domestic
    ) -> FlightBookingState {
        FlightBookingState(
            departDate: DateTime(2026, 9, 2),
            scope: scope,
            fromLocation: from,
            toLocation: to
        )
    }

    // MARK: - scope follows the route, not the toggle

    func testYgnToMdyIsDomesticEvenWhenTheToggleSaysInternational() {
        let state = self.state(from: ygn, to: mdy, scope: .international)
        XCTAssertEqual(state.effectiveScope, .domestic)
    }

    func testYgnToBkkIsInternationalEvenWhenTheToggleSaysDomestic() {
        let state = self.state(from: ygn, to: bkk)
        XCTAssertEqual(state.effectiveScope, .international)
    }

    func testFallsBackToTheToggleWhenACountryIsUnknown() {
        XCTAssertEqual(
            state(from: ygn, to: unknown, scope: .international).effectiveScope,
            .international
        )
        XCTAssertEqual(state(from: unknown, to: mdy).effectiveScope, .domestic)
    }

    // MARK: - Domestic (YGN → MDY)

    func testDomesticMyanmarCitizenNrcForAdultsOnlyNeverAPassport() {
        let domestic = state(from: ygn, to: mdy)
        XCTAssertTrue(domestic.nrcRequiredFor(travellerIsMyanmar: true, isAdult: true))
        XCTAssertFalse(domestic.nrcRequiredFor(travellerIsMyanmar: true, isAdult: false))
        XCTAssertFalse(domestic.passportRequiredFor(travellerIsMyanmar: true))
    }

    func testDomesticForeignerPassportRequiredNoNrc() {
        let domestic = state(from: ygn, to: mdy)
        XCTAssertTrue(domestic.passportRequiredFor(travellerIsMyanmar: false))
        XCTAssertFalse(domestic.nrcRequiredFor(travellerIsMyanmar: false, isAdult: true))
    }

    func testTheReportedCaseDemandsNoPassport() {
        // A Myanmar national on a domestic YGN → MDY route was being asked for
        // a passport and its expiry date.
        let reported = state(from: ygn, to: mdy, scope: .international)
        XCTAssertFalse(reported.passportRequiredFor(travellerIsMyanmar: true))
    }

    // MARK: - International (YGN → BKK)

    func testInternationalMyanmarCitizenNrcAndPassportForEveryTraveller() {
        let international = state(from: ygn, to: bkk)
        for isAdult in [true, false] {
            XCTAssertTrue(
                international.nrcRequiredFor(travellerIsMyanmar: true, isAdult: isAdult),
                "NRC required for adult=\(isAdult)"
            )
        }
        XCTAssertTrue(international.passportRequiredFor(travellerIsMyanmar: true))
    }

    func testInternationalForeignerPassportForEveryTravellerNoNrc() {
        let international = state(from: ygn, to: bkk)
        XCTAssertTrue(international.passportRequiredFor(travellerIsMyanmar: false))
        for isAdult in [true, false] {
            XCTAssertFalse(international.nrcRequiredFor(travellerIsMyanmar: false, isAdult: isAdult))
        }
    }
}
