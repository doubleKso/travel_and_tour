// Port of test/features/ticket/domain/entities/ticket_passenger_test.dart
import XCTest
@testable import EpicWorld

/// A traveller entry exactly as the Traveller Information form builds it for
/// `holdFlight` (see `_maiHoldRequest` in booking_detail_page.dart).
private func formEntry(
    title: String = "Mr",
    firstName: String = "Zeck",
    lastName: String = "Dhwye",
    nrc: String = "",
    passportNo: String = "MA123456"
) -> JSON {
    [
        "title": title,
        "firstName": firstName,
        "lastName": lastName,
        "type": "adult",
        "gender": "male",
        "dob": "1990-04-11",
        "nationality": "MM",
        "nrc": nrc,
        "passportNo": passportNo,
        "passportExpiry": "2030-04-11",
        "issuedCountry": "MM",
        "remark": NSNull(),
    ]
}

final class TicketPassengerTests: XCTestCase {
    func testATravellerCarriesWhatTheCustomerActuallyTyped() {
        let traveller = TicketPassenger.fromHoldRequest(formEntry(), phone: "+95 9259807040")

        XCTAssertEqual(traveller.fullName, "Mr Zeck Dhwye")
        XCTAssertEqual(traveller.passportNo, "MA123456")
        XCTAssertEqual(traveller.documentNumber, "MA123456")
        XCTAssertEqual(traveller.phone, "+95 9259807040")
        XCTAssertEqual(traveller.type, "adult")
    }

    func testADomesticTravellerFallsBackToTheirNrc() {
        let traveller = TicketPassenger.fromHoldRequest(
            formEntry(nrc: "12/OUKAMA(N)123456", passportNo: "")
        )

        XCTAssertTrue(traveller.passportNo.isEmpty)
        XCTAssertEqual(traveller.documentNumber, "12/OUKAMA(N)123456")
    }

    func testAMissingDocumentReadsAsEmptyNeverAsAnotherPassenger() {
        let traveller = TicketPassenger.fromHoldRequest(formEntry(nrc: "", passportNo: ""))

        XCTAssertTrue(traveller.documentNumber.isEmpty)
    }

    func testTheNameSkipsPartsTheCustomerLeftBlank() {
        let traveller = TicketPassenger.fromHoldRequest(formEntry(title: "", lastName: ""))

        XCTAssertEqual(traveller.fullName, "Zeck")
    }

    func testATicketNumberIsOnlyEverWhatTheBackendReported() {
        XCTAssertTrue(TicketPassenger.fromHoldRequest(formEntry()).ticketNumber.isEmpty)
        XCTAssertEqual(
            TicketPassenger.fromHoldRequest(formEntry(), ticketNumber: "0802401234567").ticketNumber,
            "0802401234567"
        )
    }

    func testEveryTravellerOnTheBookingKeepsTheirOwnDetails() {
        // The bug this guards: one name and one document rendered for everyone.
        let travellers = [
            formEntry(firstName: "Zeck", passportNo: "MA111111"),
            formEntry(title: "Ms", firstName: "Aye", passportNo: "MA222222"),
        ].map { TicketPassenger.fromHoldRequest($0, phone: "+95 1") }

        XCTAssertEqual(travellers.map(\.fullName), ["Mr Zeck Dhwye", "Ms Aye Dhwye"])
        XCTAssertEqual(travellers.map(\.documentNumber), ["MA111111", "MA222222"])
    }
}
