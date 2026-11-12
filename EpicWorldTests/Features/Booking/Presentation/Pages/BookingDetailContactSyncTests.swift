import XCTest
@testable import EpicWorld

/// Ports the logic assertions of
/// test/features/booking/presentation/pages/booking_detail_contact_sync_test.dart.
///
/// The Dart test pumps `BookingDetailPage`; the prefill and contact-sync rules
/// it checks live in `BookingDetailScreenState` here, so they are driven
/// directly. Layout assertions (field positions, chevron order) are widget
/// finders and are not ported.
@MainActor
final class BookingDetailContactSyncTests: XCTestCase {
    private func flight(bookable: Bool) -> TripOptionModel {
        TripOptionModel(
            id: bookable ? "mai-8M335" : "mna-UB101",
            mode: .flight,
            operatorName: bookable ? "MAI Airway" : "Myanmar National Airlines",
            operatorLogoUrl: "",
            carrierCode: bookable ? "8M" : "UB",
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
            bookable: bookable
        )
    }

    /// `NationalityChanged(Nationality.foreigner)` then `OutboundSelected(...)`.
    private func booking(bookable: Bool) -> FlightBookingState {
        FlightBookingState(
            departDate: DateTime(2026, 9, 2),
            nationality: .foreigner,
            selectedOutbound: flight(bookable: bookable)
        )
    }

    private var user: AuthUser {
        AuthUser(
            id: "member-1",
            username: "may",
            email: "may@example.com",
            displayName: "May Thu"
        )
    }

    private func account() -> MemberAccount {
        MemberAccount.fromJson([
            "id": "member-1",
            "name": "May Thu",
            "email": "may@example.com",
            "phoneNumber": "+959123456789",
        ])
    }

    func testSignedInAccountFillsTheContactForm() {
        let state = BookingDetailScreenState()
        state.initState(booking: booking(bookable: true), user: user, memberAccount: account())

        // The signed-in account fills the contact form, including a profile phone
        // number returned separately by GetMe.
        XCTAssertEqual(state.contactFirstName.text, "May")
        XCTAssertEqual(state.contactLastName.text, "Thu")
        XCTAssertEqual(state.contactEmail.text, "may@example.com")
        XCTAssertEqual(state.contactPhone.text, "9123456789")
        XCTAssertEqual(state.contactCountryCode, "+95")
    }

    func testGetMeArrivingLaterCompletesThePhone() {
        let state = BookingDetailScreenState()
        // The session has no phone; GetMe answers after the page opened.
        state.initState(booking: booking(bookable: true), user: user, memberAccount: nil)
        XCTAssertEqual(state.contactPhone.text, "")

        state.prefillFromMemberAccount(account())

        XCTAssertEqual(state.contactPhone.text, "9123456789")
        XCTAssertEqual(state.bkPhone.text, "9123456789")
    }

    func testSameAsContactKeepsTravellerNamesLive() {
        let state = BookingDetailScreenState()
        state.initState(booking: booking(bookable: true), user: user, memberAccount: account())

        state.contactFirstName.text = "John"
        state.contactLastName.text = "Doe"
        state.toggleSameAsContact(0, true)

        XCTAssertEqual(state.travFirst[0].text, "John")
        XCTAssertEqual(state.travLast[0].text, "Doe")

        state.contactFirstName.text = "Jane"
        state.contactLastName.text = "Smith"

        XCTAssertEqual(state.travFirst[0].text, "Jane")
        XCTAssertEqual(state.travLast[0].text, "Smith")
    }

    func testEnquiryFormIsPrefilledFromTheSameAccount() {
        let state = BookingDetailScreenState()
        state.initState(booking: booking(bookable: false), user: user, memberAccount: account())

        XCTAssertEqual(state.bkName.text, "May Thu")
        XCTAssertEqual(state.bkPhone.text, "9123456789")
        XCTAssertEqual(state.bkEmail.text, "may@example.com")
        XCTAssertEqual(state.bkCountryCode, "+95")
    }

    func testProfilePhoneKeepsOnlyTheLocalNumber() {
        let state = BookingDetailScreenState()
        let value = state.profilePhoneValue("+959123456789", fallbackCountryCode: "+66")
        XCTAssertEqual(value.countryCode, "+95")
        XCTAssertEqual(value.localNumber, "9123456789")
    }
}
