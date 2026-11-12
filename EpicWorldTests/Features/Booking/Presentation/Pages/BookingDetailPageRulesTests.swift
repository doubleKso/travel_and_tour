import XCTest
@testable import EpicWorld

/// Ports test/features/booking/presentation/pages/email_format_test.dart and
/// passport_expiry_test.dart. The Dart tests mirror the page's private
/// `_emailPattern` and `_passportExpiryFloor` / `_passportExpiryValidator`;
/// here they exercise `BookingDetailScreenState` itself.
@MainActor
final class BookingDetailPageRulesTests: XCTestCase {
    // MARK: - email_format_test.dart

    private func emailMatches(_ value: String) -> Bool {
        BookingDetailScreenState.hasMatch(BookingDetailScreenState.emailPattern, value)
    }

    func testAcceptsAddressesFromAllThreeSupportedDomains() {
        for ok in [
            "you@email.com",
            "you@gmail.com",
            "you@systematic-business.com",
            "first.last+tag@systematic-business.com",
            "User@GMAIL.COM",
        ] {
            XCTAssertTrue(emailMatches(ok), ok)
        }
    }

    func testRejectsOtherDomainsAndMalformedAddresses() {
        for bad in [
            "",
            "you",
            "you@",
            "@systematic-business.com",
            "you@yahoo.com",
            "you@googlemail.com",
            "you@systematic-business.com.mm",
            "you@sub.systematic-business.com",
            "you systematic-business.com",
            "you@@systematic-business.com",
        ] {
            XCTAssertFalse(emailMatches(bad), bad)
        }
    }

    // MARK: - passport_expiry_test.dart

    private var now: DateTime { DateTime(2026, 9, 15) }

    private func validate(_ value: String?) -> String? {
        BookingDetailScreenState().passportExpiryValidator(value, now: now)
    }

    func testFloorIsTheFirstOfTheMonthSixMonthsOut() {
        XCTAssertEqual(BookingDetailScreenState.passportExpiryFloor(now), DateTime(2027, 3, 1))
    }

    func testFloorRollsOverTheYearBoundary() {
        XCTAssertEqual(BookingDetailScreenState.passportExpiryFloor(DateTime(2026, 11, 2)), DateTime(2027, 5, 1))
        XCTAssertEqual(BookingDetailScreenState.passportExpiryFloor(DateTime(2026, 12, 31)), DateTime(2027, 6, 1))
    }

    func testRejectsAnExpiryInsideTheSixMonthWindow() {
        XCTAssertNotNil(validate("28/02/2027"))
        XCTAssertNotNil(validate("01/01/2027"))
    }

    func testRejectsAnAlreadyExpiredPassport() {
        XCTAssertNotNil(validate("01/01/2020"))
    }

    func testAcceptsTheFirstAcceptableDayAndBeyond() {
        XCTAssertNil(validate("01/03/2027"))
        XCTAssertNil(validate("15/08/2030"))
    }

    func testStillReportsEmptyAndMalformedInput() {
        XCTAssertEqual(validate(""), "This field is required.")
        XCTAssertEqual(validate("31/02/2027"), "Enter a valid date.")
    }

    func testExpiryMessageNamesTheFloorMonth() {
        XCTAssertEqual(validate("28/02/2027"), "Passport must be valid until March 2027 or later.")
    }
}
