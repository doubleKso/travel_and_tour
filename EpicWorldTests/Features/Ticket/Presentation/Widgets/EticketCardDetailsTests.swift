// Port of test/features/ticket/presentation/widgets/eticket_card_details_test.dart
//
// The Dart file is a widget test (finders over the rendered card). Its
// assertions on computed values are ported as unit tests of the `ETicketCard`
// helpers that compute them; static copy and plain field pass-through are not.
import XCTest
@testable import EpicWorld

/// The booking from the web e-ticket: EW-8L9VFJ / 17T1EK, RGN → SIN on 8M233.
private func webTicket() -> TicketModel {
    TicketModel(
        id: "2800d9f3-5af6-4442-9157-3e9f9cc4bb5a",
        bookingReference: "EW-8L9VFJ",
        outbound: TripOptionModel(
            id: "EW-8L9VFJ-out",
            mode: .flight,
            operatorName: "Myanmar Airways",
            operatorLogoUrl: "",
            originCode: "RGN",
            originName: "Yangon",
            destinationCode: "SIN",
            destinationName: "Singapore",
            departure: DateTime(2026, 10, 23, 15, 40),
            arrival: DateTime(2026, 10, 23, 20, 10),
            stops: 0,
            travelClass: .economy,
            price: 492507,
            currency: "MMK",
            flightNumber: "8M233",
            aircraft: "A319-112",
            arrivalTerminal: "2",
            baggageKg: 30,
            fareBrand: "IECO PROMO"
        ),
        inbound: nil,
        passengerName: "Mrs Myet Noe",
        seatCount: 2,
        totalPaid: 197,
        currency: "MMK",
        issuedAt: DateTime(2026, 10, 21, 8, 42),
        qrPayload: "17T1EK|EW-8L9VFJ",
        pnr: "17T1EK",
        contactName: "Kaung Khant SBS",
        passengers: [
            TicketPassenger(
                title: "Mrs",
                firstName: "Myet",
                lastName: "Noe",
                type: "adult",
                passportNo: "MA1235401",
                phone: "+95 9259807040",
                ticketNumber: "5992403209247"
            ),
            TicketPassenger(
                firstName: "Aye",
                lastName: "Noe",
                type: "child",
                nrc: "14/MaPaNa(N)943783",
                phone: "+95 9259807040"
            ),
        ]
    )
}

final class EticketCardDetailsTests: XCTestCase {
    @MainActor
    func testTheETicketShowsTheSameDetailsAsTheWebETicket() {
        let ticket = webTicket()
        let leg = ticket.outbound

        // Booking strip.
        XCTAssertEqual(ETicketCard.airlines(ticket).uppercased(), "MYANMAR AIRWAYS")

        // Flight card: route, flight number / aircraft, terminal.
        XCTAssertEqual(ETicketCard.segmentRoute(leg), "Yangon → Singapore")
        XCTAssertEqual(ETicketCard.flightLine(leg), "8M233 · A319-112")
        XCTAssertEqual(ETicketCard.terminalLabel("2"), "Terminal 2")
        XCTAssertEqual(ETicketCard.terminalLabel("Terminal 3"), "Terminal 3")

        // Passengers: one block per entered traveller, type, real ticket
        // number, masked documents.
        XCTAssertEqual(ETicketCard.passengerCount(ticket), 2)
        XCTAssertEqual(ETicketCard.passengerName(ticket, 0).uppercased(), "MRS MYET NOE")
        XCTAssertEqual(ETicketCard.passengerTypeLabel("adult"), LocaleKeys.ticket_adult.tr())
        XCTAssertEqual(ETicketCard.passengerTypeLabel("child"), LocaleKeys.ticket_child.tr())
        XCTAssertEqual(ETicketCard.passengerTypeLabel("infant"), LocaleKeys.ticket_infant.tr())
        XCTAssertEqual(ETicketCard.passengerTypeLabel(nil), LocaleKeys.ticket_adult.tr())
        XCTAssertEqual(ETicketCard.ticketNumber(ticket, 0), "5992403209247")
        XCTAssertEqual(ETicketCard.ticketNumber(ticket, 1), "EW-8L9VFJ-2")
        XCTAssertEqual(ETicketCard.masked("MA1235401"), "••••5401")
        XCTAssertEqual(ETicketCard.masked("14/MaPaNa(N)943783"), "••••3783")
        XCTAssertFalse(ETicketCard.masked("MA1235401").contains("MA1235401"))
        XCTAssertEqual(ETicketCard.documentLabel(passport: "", nrc: "14/MaPaNa(N)943783"), LocaleKeys.booking_nrc.tr())
        XCTAssertEqual(ETicketCard.documentLabel(passport: "MA1235401", nrc: ""), LocaleKeys.common_passport.tr())

        // Per-flight row: real flight number, real bags.
        XCTAssertEqual(ETicketCard.passengerFlightRoute(leg), "RGN → SIN · 23 Oct · 8M233")
        XCTAssertEqual(ETicketCard.bags(leg), "30 kg")
    }

    @MainActor
    func testFallbacksForTicketsWithoutEnteredTravellers() {
        let base = webTicket()
        let legacy = TicketModel(
            id: "t1",
            bookingReference: "",
            outbound: base.outbound,
            inbound: nil,
            passengerName: "Hein Htet Zaw",
            seatCount: 2,
            totalPaid: 1,
            currency: "MMK",
            issuedAt: base.issuedAt,
            qrPayload: ""
        )

        XCTAssertEqual(ETicketCard.passengerCount(legacy), 2)
        XCTAssertEqual(ETicketCard.passengerName(legacy, 1), "Hein Htet Zaw")
        // Short ids are not sliced past their end.
        XCTAssertEqual(ETicketCard.ticketNumber(legacy, 1), "t12")
        XCTAssertEqual(ETicketCard.masked(""), "—")
        XCTAssertEqual(ETicketCard.masked("1234"), "1234")
    }
}
