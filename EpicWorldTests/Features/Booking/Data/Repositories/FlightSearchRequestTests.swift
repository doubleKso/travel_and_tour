import XCTest
@testable import EpicWorld

/// Port of test/features/booking/data/repositories/flight_search_request_test.dart.
final class FlightSearchRequestTests: XCTestCase {
    func testMapsARoundTripSearchToTheCallableDataObject() {
        let request = FlightSearchRequest(
            from: "RGN",
            to: "MDL",
            departDate: "2026-11-15",
            returnDate: "2026-11-20",
            adults: 1,
            children: 0,
            infants: 0,
            cabin: "Economy",
            nationality: "MM"
        )

        XCTAssertEqual(
            NSDictionary(dictionary: request.toJson()),
            NSDictionary(dictionary: [
                "from": "RGN",
                "to": "MDL",
                "departDate": "2026-11-15",
                "returnDate": "2026-11-20",
                "adults": 1,
                "children": 0,
                "infants": 0,
                "cabin": "Economy",
                "nationality": "MM",
            ])
        )
        XCTAssertNotNil(FlightSearchCallableService.self)
        XCTAssertNotNil(BookingRepositoryImpl.self)
    }

    func testLeavesReturnDateOutOfAOneWaySearch() {
        let request = FlightSearchRequest(
            from: "RGN",
            to: "BKK",
            departDate: "2026-09-02",
            adults: 2,
            children: 1,
            infants: 0,
            cabin: "Economy",
            nationality: "MM"
        )

        XCTAssertFalse(request.toJson().keys.contains("returnDate"))
    }

    func testCarriesTheBusinessCabinThroughToThePayload() {
        let request = FlightSearchRequest(
            from: "RGN",
            to: "BKK",
            departDate: "2026-09-02",
            adults: 1,
            children: 0,
            infants: 0,
            cabin: "Business",
            nationality: "MM"
        )

        XCTAssertEqual(Dart.str(request.toJson()["cabin"]), "Business")
    }

    func testNationalityOptionsMapToTheirDropdownLabelAndRequestCode() {
        XCTAssertEqual(Nationality.myanmar.label, "Myanmar")
        XCTAssertEqual(Nationality.myanmar.code, "MM")
        XCTAssertEqual(Nationality.foreigner.label, "Other")
        XCTAssertEqual(Nationality.foreigner.code, "OTHER")
    }
}
