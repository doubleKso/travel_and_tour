import XCTest
@testable import EpicWorld

/// Port of test/features/booking/domain/usecases/load_guest_booking_checkout_use_case_test.dart.
final class LoadGuestBookingCheckoutUseCaseTests: XCTestCase {
    private final class Repository: GuestBookingRepository {
        let answer: AppResult<GuestBookingLookup>
        var asked: (reference: String, email: String)?

        init(_ answer: AppResult<GuestBookingLookup>) {
            self.answer = answer
        }

        func findGuestBooking(reference: String, email: String) async -> AppResult<GuestBookingLookup> {
            asked = (reference: reference, email: email)
            return answer
        }
    }

    private func lookup(status: String = "held", message: String = "") -> GuestBookingLookup {
        let text = #"""
        {
          "ok": true,
          "message": "\#(message)",
          "booking": {
            "reference": "EW-8F4PHA",
            "pnr": "17RJ5B",
            "status": "\#(status)",
            "route": "RGN → BKK",
            "total": 412641,
            "currency": "MMK",
            "adults": 1,
            "contactEmail": "someone@gmail.com"
          },
          "segments": [
            {
              "direction": "outbound",
              "fromCode": "RGN",
              "toCode": "BKK",
              "travelDate": "2026-09-06"
            }
          ]
        }
        """#
        return GuestBookingLookup.fromJson(Dart.map(try! jsonDecode(text))!)
    }

    func testAsksForBothFieldsBeforeLookingAnythingUp() async {
        let repository = Repository(.success(lookup()))

        let outcome = await LoadGuestBookingCheckoutUseCase(repository)((
            reference: "  ",
            email: "someone@gmail.com"
        ))

        XCTAssertNil(repository.asked)
        XCTAssertNil(outcome.checkout)
        XCTAssertNil(outcome.record)
        XCTAssertEqual(outcome.error, "Enter both the booking reference and the email used to book.")
    }

    func testNormalisesThePairItSends() async {
        let repository = Repository(.success(lookup()))

        _ = await LoadGuestBookingCheckoutUseCase(repository)((
            reference: " ew-8f4pha ",
            email: " someone@gmail.com "
        ))

        XCTAssertEqual(repository.asked?.reference, "EW-8F4PHA")
        XCTAssertEqual(repository.asked?.email, "someone@gmail.com")
    }

    func testAFailedLookupSurfacesTheFailuresMessage() async {
        let outcome = await LoadGuestBookingCheckoutUseCase(
            Repository(.failure(.server(message: "Try again later.")))
        )((reference: "EW-1", email: "someone@gmail.com"))

        XCTAssertNil(outcome.checkout)
        XCTAssertNil(outcome.record)
        XCTAssertEqual(outcome.error, "Try again later.")
    }

    func testNoMatchingBookingUsesTheBackendWordingWhenItHasOne() async {
        let outcome = await LoadGuestBookingCheckoutUseCase(
            Repository(.success(GuestBookingLookup.fromJson(["message": "Nothing found."])))
        )((reference: "EW-1", email: "someone@gmail.com"))

        XCTAssertEqual(outcome.error, "Nothing found.")
    }

    func testAPaidBookingReturnsItsRecordSoTheCardCanUpdate() async {
        let outcome = await LoadGuestBookingCheckoutUseCase(
            Repository(.success(lookup(status: "confirmed")))
        )((reference: "EW-8F4PHA", email: "someone@gmail.com"))

        XCTAssertNil(outcome.checkout)
        XCTAssertEqual(outcome.record?.status, GuestBookingStatus.confirmed)
        XCTAssertEqual(
            outcome.error,
            "This booking is already paid — check your email for the e-ticket."
        )
    }

    func testAHeldBookingBecomesAResumableCheckout() async {
        let outcome = await LoadGuestBookingCheckoutUseCase(
            Repository(.success(lookup()))
        )((reference: "EW-8F4PHA", email: "someone@gmail.com"))

        XCTAssertNil(outcome.error)
        XCTAssertNotNil(outcome.checkout)
        XCTAssertEqual(outcome.record?.reference, "EW-8F4PHA")
        XCTAssertEqual(outcome.record?.travelDate, "2026-09-06")
        XCTAssertEqual(outcome.checkout?.resume.holdResponse.pnr, "17RJ5B")
    }
}
