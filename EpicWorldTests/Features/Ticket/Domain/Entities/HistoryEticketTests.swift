// Port of test/features/ticket/domain/entities/history_eticket_test.dart
import XCTest
@testable import EpicWorld

final class HistoryEticketTests: XCTestCase {
    private let booking = BookingHistoryItem.fromJson([
        "id": "booking-1",
        "reference": "EW-DGPZNC",
        "pnr": "17RDGN",
        "status": "confirmed",
        "route": "RGN → SIN",
        "cabin": "economy",
        "currency": "MMK",
        "total": 451200,
        "adults": 1,
        "contactFullName": "Ci Phat",
        "contactTitle": "Mr",
        "contactCountryCode": "+95",
        "contactPhone": "9259807040",
        "createdAt": "2026-09-01T07:18:42.000Z",
        "ticketedAt": "2026-09-01T08:00:00.000Z",
    ])

    private let detail = BookingHistoryDetail(
        segments: [
            BookingHistorySegment.fromJson([
                "direction": "outbound",
                "fromCode": "RGN",
                "toCode": "SIN",
                "fromCity": "Yangon",
                "toCity": "Singapore",
                "travelDate": "2026-09-02",
                "departTime": "07:25 AM",
                "arriveTime": "12:05 PM",
                "flightNo": "8M231",
                "carrierName": "MYANMAR AIRWAYS",
                "cabin": "economy",
                "price": 451200,
            ]),
        ],
        passengers: [
            BookingHistoryPassenger.fromJson([
                "title": "Mr",
                "firstName": "Ci",
                "lastName": "Phat",
                "type": "adult",
                "nrc": "14/MaPaNa(N)943783",
            ]),
        ]
    )

    func testAConfirmedHistoryBookingIsEligibleForAnETicket() {
        XCTAssertTrue(booking.isConfirmed)
        XCTAssertFalse(BookingHistoryItem.fromJson(["status": "held"]).isConfirmed)
        XCTAssertTrue(BookingHistoryItem.fromJson(["status": "ticketed"]).isConfirmed)
    }

    func testBuildsTheSharedETicketFromHistoryFlightAndPassengerData() {
        let ticket = HistoryETicket.from(booking, detail)

        XCTAssertEqual(ticket.bookingReference, "EW-DGPZNC")
        XCTAssertEqual(ticket.pnr, "17RDGN")
        XCTAssertEqual(ticket.contactName, "Ci Phat")
        XCTAssertEqual(ticket.outbound.originCode, "RGN")
        XCTAssertEqual(ticket.outbound.destinationCode, "SIN")
        XCTAssertEqual(ticket.outbound.flightNumber, "8M231")
        XCTAssertEqual(ticket.passengers.count, 1)
        XCTAssertEqual(ticket.passengers.first?.fullName, "Mr Ci Phat")
        XCTAssertEqual(ticket.passengers.first?.phone, "+95 9259807040")
        XCTAssertEqual(ticket.totalPaid, 451200)
        XCTAssertEqual(ticket.discount, 0)
        XCTAssertEqual(ticket.promotion, 0)
    }

    func testCarriesTheBookingPromotionOntoTheETicket() {
        // Pricing fields as `GetMyBookings` returns them for a promo booking.
        let discounted = BookingHistoryItem.fromJson([
            "id": "2800d9f3-5af6-4442-9157-3e9f9cc4bb5a",
            "reference": "EW-8L9VFJ",
            "pnr": "17T1EK",
            "status": "confirmed",
            "currency": "MMK",
            "adults": 1,
            "baseFare": 492507,
            "perPaxFare": 492507,
            "totalBeforePromo": 492507,
            "promotion": 492310,
            "total": 197,
        ])

        let ticket = HistoryETicket.from(discounted, detail)

        XCTAssertEqual(discounted.promotion, 492310)
        XCTAssertEqual(ticket.totalPaid, 197)
        XCTAssertEqual(ticket.promotion, 492310)
        XCTAssertEqual(ticket.discount, 492310)
        // The record keeps no code, only the amount.
        XCTAssertTrue(ticket.promoCode.isEmpty)
    }
}
