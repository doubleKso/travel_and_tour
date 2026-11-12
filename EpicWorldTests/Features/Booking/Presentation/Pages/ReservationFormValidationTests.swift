import XCTest
@testable import EpicWorld

/// Ports the logic assertions of
/// test/features/booking/presentation/pages/reservation_form_validation_test.dart:
/// the Booking Form's phone, email and traveller rules, the submit gate, and
/// the enquiry's international phone number. The Dart test walks the widget;
/// here `BookingDetailScreenState` is driven directly.
@MainActor
final class ReservationFormValidationTests: XCTestCase {
    /// A non-MAI flight, which is what a Commercial Flights enquiry books.
    private func flight() -> TripOptionModel {
        TripOptionModel(
            id: "mna-UB101",
            mode: .flight,
            operatorName: "Myanmar National Airlines",
            operatorLogoUrl: "",
            carrierCode: "UB",
            originCode: "RGN",
            originName: "Yangon",
            destinationCode: "MDL",
            destinationName: "Mandalay",
            departure: DateTime(2026, 9, 2, 7, 25),
            arrival: DateTime(2026, 9, 2, 9, 15),
            stops: 0,
            travelClass: .economy,
            price: 375435,
            currency: "MMK",
            bookable: false
        )
    }

    /// A signed-out customer on the Booking Form.
    private func makeState() -> BookingDetailScreenState {
        let state = BookingDetailScreenState()
        state.initState(
            booking: FlightBookingState(departDate: DateTime(2026, 9, 2), selectedOutbound: flight()),
            user: nil,
            memberAccount: nil
        )
        return state
    }

    private func nameError(_ state: BookingDetailScreenState) -> String? {
        state.reservationError(state.requiredValue(state.bkName.text, label: "Full name"))
    }

    private func phoneError(_ state: BookingDetailScreenState) -> String? {
        state.reservationError(state.phoneValidator(state.bkPhone.text, countryCode: state.bkCountryCode))
    }

    private func travellersError(_ state: BookingDetailScreenState) -> String? {
        state.reservationError(state.travellersValidator(state.bkTravellers.text))
    }

    func testEmptyFormNamesEveryMissingField() {
        let state = makeState()

        // Nothing shows until a submit has been tried.
        XCTAssertNil(nameError(state))
        XCTAssertNil(phoneError(state))
        XCTAssertNil(state.bkEmailFieldError())

        // An empty form names every missing field under the field itself.
        state.showReservationValidation = true
        XCTAssertFalse(state.validateReservationForm())
        XCTAssertEqual(nameError(state), "Full name is required.")
        XCTAssertEqual(phoneError(state), "Mobile number is required.")
        XCTAssertEqual(state.bkEmailFieldError(), "Email is required.")
        // The traveller count starts at the searched number.
        XCTAssertEqual(state.bkTravellers.text, "1")
        XCTAssertNil(travellersError(state))
    }

    func testMalformedValuesAreCaught() {
        let state = makeState()
        state.showReservationValidation = true

        state.bkName.text = "May Thu"
        state.bkPhone.text = "12345"
        state.bkEmail.text = "may@yahoo.com"
        state.bkTravellers.text = "27"

        XCTAssertNil(nameError(state))
        XCTAssertEqual(phoneError(state), "Enter a valid phone number.")
        XCTAssertEqual(
            state.bkEmailFieldError(),
            "Invalid email format! Use @gmail.com or @email.com."
        )
        XCTAssertEqual(travellersError(state), "Up to 9 travellers per booking.")

        // A +95 number has to be a Myanmar mobile, not just any six digits.
        state.bkPhone.text = "123456789"
        XCTAssertEqual(phoneError(state), "Enter a valid phone number.")

        XCTAssertFalse(state.validateReservationForm())
    }

    func testFixedValuesClearTheirErrorsAndTheEnquiryGoesOut() {
        let state = makeState()
        state.showReservationValidation = true
        state.bkName.text = "May Thu"

        state.bkPhone.text = "09123456789"
        state.bkEmail.text = "may@gmail.com"
        state.bkTravellers.text = "3"

        XCTAssertNil(phoneError(state))
        XCTAssertNil(state.bkEmailFieldError())
        XCTAssertNil(travellersError(state))
        XCTAssertTrue(state.validateReservationForm())

        // What `_submitBooking` puts on the request.
        XCTAssertEqual(BookingDetailScreenState.trim(state.bkName.text), "May Thu")
        XCTAssertEqual(
            state.internationalPhone(state.bkCountryCode, BookingDetailScreenState.trim(state.bkPhone.text)),
            "+9509123456789"
        )
        XCTAssertEqual(BookingDetailScreenState.trim(state.bkEmail.text), "may@gmail.com")
        XCTAssertEqual(Dart.parseInt(BookingDetailScreenState.trim(state.bkTravellers.text)), 3)
    }

    func testEmailValidatesAsSoonAsItIsChanged() {
        let state = makeState()
        // The email field carries its own `AutovalidateMode.onUserInteraction`.
        state.bkEmail.text = "may@yahoo.com"
        XCTAssertEqual(
            state.bkEmailFieldError(),
            "Invalid email format! Use @gmail.com or @email.com."
        )
        // The other fields wait for a submit.
        state.bkPhone.text = "12345"
        XCTAssertNil(phoneError(state))
    }

    func testPreferredDateFallsBackToTheFlightDay() {
        let state = makeState()
        XCTAssertEqual(state.bkDate.text, "02/09/2026")
        XCTAssertEqual(state.enquiryDate(DateTime(2026, 10, 1)), "2026-09-02")

        state.bkDate.text = "31/02/2026"
        XCTAssertEqual(state.enquiryDate(DateTime(2026, 10, 1)), "2026-10-01")
    }
}
