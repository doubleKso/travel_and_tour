// Port of test/features/ticket/domain/entities/held_booking_resume_test.dart
import XCTest
@testable import EpicWorld

/// The record `dcExec:GetMyBookingByRef` returns, verbatim.
private func payload() -> JSON {
    [
        "taxes": 0,
        "agentDiscount": 0,
        "totalBeforePromo": 505818,
        "total": 303,
        "status": "held",
        "pnr": "17RHFC",
        "reference": "EW-SUK2R7",
        "perPaxFare": 505818,
        "promotion": 505515,
        "userId": "848e3221-d4d4-4c26-8506-0346b9ece321",
        "paymentMethod": NSNull(),
        "contactFullName": "Zeck Dhwye",
        "createdAt": "2026-08-31T09:17:32.331587Z",
        "adults": 1,
        "id": "2b06fb0c-41b0-4103-bb44-3ed268bca987",
        "contactCountryCode": "+95",
        "contactEmail": "sjbudv0wrv@gmail.com",
        "ticketedAt": NSNull(),
        "bookingDeadline": "2026-09-01T09:17:30.000000Z",
        "infants": 0,
        "contactTitle": "Mr",
        "baseFare": 505818,
        "cabin": "economy",
        "fareDiscount": 0,
        "convenienceFees": 0,
        "currency": "MMK",
        "route": "RGN → SIN",
        "mode": "flight",
        "agentDiscountPct": 0,
        "tripType": "one-way",
        "airlineTaxes": 0,
        "supplier": "mai",
        "children": 0,
        "ticketTimeLimit": "2026-09-01T09:17:30.000000Z",
        "contactPhone": "9259807040",
    ]
}

private func segment(direction: String = "outbound") -> BookingHistorySegment {
    BookingHistorySegment.fromJson([
        "direction": direction,
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
        "stops": 0,
        "baggageKg": 30,
        "price": 505818,
        "refundable": false,
        "fareBrand": "IECO PROMO",
    ])
}

final class HeldBookingResumeTests: XCTestCase {
    private let booking = BookingHistoryItem.fromJson(payload())

    func testTheHeldBookingParsesAsUnpaid() {
        XCTAssertTrue(booking.isHeld)
        XCTAssertEqual(booking.reference, "EW-SUK2R7")
        XCTAssertEqual(booking.total, 303)
    }

    // ---- resuming with segments

    private var resume: HeldBookingResume {
        HeldBookingResume.from(booking, segments: [segment()])
    }

    func testCarriesTheAmountStillOwedNotThePrePromoFare() {
        XCTAssertEqual(resume.holdResponse.total, 303)
        XCTAssertEqual(resume.holdResponse.perPax, 505818)
        XCTAssertEqual(resume.holdResponse.currency, "MMK")
    }

    func testKeepsTheReferenceAndPnrThePaymentConfirmsAgainst() {
        XCTAssertEqual(resume.holdResponse.reference, "EW-SUK2R7")
        XCTAssertEqual(resume.holdResponse.pnr, "17RHFC")
        XCTAssertEqual(resume.holdResponse.bookingId, booking.id)
        XCTAssertTrue(resume.holdResponse.ok)
    }

    func testRebuildsTheItineraryFromTheSegment() {
        let resume = self.resume
        XCTAssertEqual(resume.outbound.originCode, "RGN")
        XCTAssertEqual(resume.outbound.destinationCode, "SIN")
        XCTAssertEqual(resume.outbound.flightNumber, "8M231")
        XCTAssertEqual(resume.outbound.operatorName, "MYANMAR AIRWAYS")
        XCTAssertEqual(resume.outbound.departure, DateTime(2026, 9, 2, 7, 25))
        XCTAssertEqual(resume.outbound.arrival, DateTime(2026, 9, 2, 12, 5))
        XCTAssertEqual(resume.departDate, DateTime(2026, 9, 2, 7, 25))
        XCTAssertNil(resume.inbound, "one-way booking")
    }

    func testCarriesTheContactTheTicketIsConfirmedWith() {
        let resume = self.resume
        XCTAssertEqual(resume.holdRequest.contact["email"] as? String, "sjbudv0wrv@gmail.com")
        XCTAssertEqual(resume.holdRequest.contact["fullName"] as? String, "Zeck Dhwye")
        XCTAssertEqual(resume.holdRequest.contact["phone"] as? String, "9259807040")
        XCTAssertEqual(resume.holdRequest.selections.count, 1)
    }

    func testCarriesPassengersAndCabin() {
        let resume = self.resume
        XCTAssertEqual(resume.adults, 1)
        XCTAssertEqual(resume.children, 0)
        XCTAssertEqual(resume.infants, 0)
        XCTAssertEqual(resume.cabinClass, TravelClass.economy)
        XCTAssertEqual(resume.holdResponse.passengers, 1)
    }

    func testFallsBackToTheRouteStringWhenSegmentsAreUnavailable() {
        let resume = HeldBookingResume.from(booking)

        XCTAssertEqual(resume.outbound.originCode, "RGN")
        XCTAssertEqual(resume.outbound.destinationCode, "SIN")
        XCTAssertEqual(resume.from.code, "RGN")
        XCTAssertEqual(resume.to.code, "SIN")
        XCTAssertEqual(resume.holdResponse.total, 303)
    }

    // ---- route parsing

    func testRouteParsingSplitsOnTheArrowTheServerSends() {
        XCTAssertEqual(HeldBookingResume.routeCodes("RGN → SIN").from, "RGN")
        XCTAssertEqual(HeldBookingResume.routeCodes("RGN → SIN").to, "SIN")
        XCTAssertEqual(HeldBookingResume.routeCodes("RGN - MDL").to, "MDL")
    }

    func testRouteParsingDegradesToEmptyCodesOnAnUnusableRoute() {
        XCTAssertEqual(HeldBookingResume.routeCodes("").from, "")
        XCTAssertEqual(HeldBookingResume.routeCodes("RGN").to, "")
    }

    // ---- time parsing

    private let fallback = DateTime(2026, 1, 1)

    func testTimeParsingReads12HourTimes() {
        XCTAssertEqual(
            HeldBookingResume.dateTimeOf("2026-09-02", "07:25 AM", fallback),
            DateTime(2026, 9, 2, 7, 25)
        )
        XCTAssertEqual(
            HeldBookingResume.dateTimeOf("2026-09-02", "12:05 PM", fallback),
            DateTime(2026, 9, 2, 12, 5)
        )
        XCTAssertEqual(
            HeldBookingResume.dateTimeOf("2026-09-02", "12:30 AM", fallback),
            DateTime(2026, 9, 2, 0, 30)
        )
        XCTAssertEqual(
            HeldBookingResume.dateTimeOf("2026-09-02", "09:15 PM", fallback),
            DateTime(2026, 9, 2, 21, 15)
        )
    }

    func testTimeParsingFallsBackOnUnusableInput() {
        XCTAssertEqual(HeldBookingResume.dateTimeOf("", "07:25 AM", fallback), fallback)
        XCTAssertEqual(
            HeldBookingResume.dateTimeOf("2026-09-02", "noon", fallback),
            DateTime(2026, 9, 2)
        )
    }

    func testAnOvernightLegLandsOnTheFollowingDay() {
        let resume = HeldBookingResume.from(
            booking,
            segments: [
                BookingHistorySegment.fromJson([
                    "direction": "outbound",
                    "fromCode": "RGN",
                    "toCode": "SIN",
                    "travelDate": "2026-09-02",
                    "departTime": "11:40 PM",
                    "arriveTime": "04:15 AM",
                    "stops": 0,
                    "price": 100,
                ]),
            ]
        )

        XCTAssertEqual(resume.outbound.departure, DateTime(2026, 9, 2, 23, 40))
        XCTAssertEqual(resume.outbound.arrival, DateTime(2026, 9, 3, 4, 15))
    }

    func testARoundTripSplitsItsLegsByDirection() {
        let resume = HeldBookingResume.from(
            booking,
            segments: [segment(), segment(direction: "return")]
        )

        XCTAssertNotNil(resume.outbound)
        XCTAssertNotNil(resume.inbound)
        XCTAssertEqual(resume.holdRequest.selections.count, 2)
    }
}
