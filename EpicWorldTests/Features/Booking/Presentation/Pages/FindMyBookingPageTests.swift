import XCTest
@testable import EpicWorld

/// Ports the logic of
/// test/features/booking/presentation/pages/find_my_booking_page_test.dart:
/// the form refuses to search on a half-filled pair, and the reference field
/// shows capitals.
@MainActor
final class FindMyBookingPageTests: XCTestCase {
    func testNothingEnteredNamesBothFields() {
        XCTAssertEqual(FindMyBookingPage.referenceValidator(""), "Booking reference is required.")
        XCTAssertEqual(FindMyBookingPage.referenceValidator(nil), "Booking reference is required.")
        XCTAssertEqual(FindMyBookingPage.referenceValidator("   "), "Booking reference is required.")
        XCTAssertEqual(FindMyBookingPage.emailValidator(""), "Email is required.")
        XCTAssertEqual(FindMyBookingPage.emailValidator(nil), "Email is required.")
    }

    func testAReferenceAloneIsNotEnoughAndTheAddressIsChecked() {
        XCTAssertNil(FindMyBookingPage.referenceValidator("ew-8f4pha"))
        XCTAssertEqual(
            FindMyBookingPage.emailValidator("not-an-address"),
            "Enter a valid email address, e.g. name@gmail.com."
        )
    }

    func testAShortReferenceAsksForTheFullOne() {
        XCTAssertEqual(
            FindMyBookingPage.referenceValidator("EW-1"),
            "Enter the full reference from your email."
        )
        XCTAssertNil(FindMyBookingPage.referenceValidator("EW-8F4PHA"))
    }

    func testValidAddressesPass() {
        XCTAssertNil(FindMyBookingPage.emailValidator("name@gmail.com"))
        XCTAssertNil(FindMyBookingPage.emailValidator("  first.last+trip@mail.example.com.mm  "))
        XCTAssertNotNil(FindMyBookingPage.emailValidator("name@gmail"))
        XCTAssertNotNil(FindMyBookingPage.emailValidator("name@@gmail.com"))
    }

    func testReferencesArePrintedInCapitalsSoThatIsWhatTheFieldShows() {
        XCTAssertEqual(UpperCaseTextFormatter().formatEditUpdate("", "ew-8f4pha"), "EW-8F4PHA")
        XCTAssertEqual(UpperCaseTextFormatter().formatEditUpdate("EW-8F4PH", "EW-8F4PHa"), "EW-8F4PHA")
    }
}
