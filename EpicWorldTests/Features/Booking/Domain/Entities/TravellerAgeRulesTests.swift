import XCTest
@testable import EpicWorld

/// Port of test/features/booking/domain/entities/traveller_age_rules_test.dart.
final class TravellerAgeRulesTests: XCTestCase {
    private let departure = DateTime(2026, 9, 14, 8, 30)

    func testAcceptsATravellerOlderThan12OnDeparture() {
        XCTAssertTrue(
            TravellerAgeRules.isOlderThan12(dateOfBirth: DateTime(2014, 9, 13), travelDate: departure)
        )
    }

    func testRejectsATravellerWhoIsExactly12OnDeparture() {
        XCTAssertFalse(
            TravellerAgeRules.isOlderThan12(dateOfBirth: DateTime(2014, 9, 14), travelDate: departure)
        )
    }

    func testClampsLeapDayBoundariesToAValidCalendarDate() {
        XCTAssertEqual(
            TravellerAgeRules.latestAdultDateOfBirth(DateTime(2100, 2, 28)),
            DateTime(2088, 2, 27)
        )
    }
}
