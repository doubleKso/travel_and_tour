import XCTest
@testable import EpicWorld

/// Port of test/features/booking/domain/entities/guest_booking_lookup_test.dart.
final class GuestBookingLookupTests: XCTestCase {
    private func json(_ text: String) throws -> JSON {
        try XCTUnwrap(Dart.map(try jsonDecode(text)))
    }

    private func stored(
        _ reference: String,
        status: String = GuestBookingStatus.pendingPayment,
        amount: Double = 100,
        pnr: String = ""
    ) -> GuestBookingRecord {
        GuestBookingRecord(
            reference: reference,
            email: "guest@gmail.com",
            route: "RGN → BKK",
            service: "flight",
            travelDate: "2026-09-06",
            savedAt: DateTime(2026, 9, 3),
            ticketTimeLimit: DateTime(2026, 9, 3, 17),
            amount: amount,
            currency: "MMK",
            status: status,
            pnr: pnr
        )
    }

    // MARK: - findGuestBooking

    func testReadsTheBookingItsLegsAndItsTravellers() throws {
        let lookup = GuestBookingLookup.fromJson(try json(#"""
        {
          "ok": true,
          "reason": "",
          "message": "",
          "booking": {
            "id": "b1",
            "reference": "EW-8F4PHA",
            "pnr": "17RJ5B",
            "status": "held",
            "route": "RGN → BKK",
            "total": 412641,
            "currency": "MMK",
            "adults": 1,
            "contactEmail": "someone@gmail.com",
            "ticketTimeLimit": "2026-09-03T17:00:00.000Z"
          },
          "segments": [
            {"direction": "outbound", "fromCode": "RGN", "toCode": "BKK"}
          ],
          "passengers": [
            {"firstName": "Tony", "lastName": "Stark"}
          ]
        }
        """#))

        XCTAssertTrue(lookup.ok)
        let booking = try XCTUnwrap(lookup.booking)
        XCTAssertEqual(booking.reference, "EW-8F4PHA")
        XCTAssertTrue(booking.isHeld)
        XCTAssertEqual(lookup.segments.count, 1)
        XCTAssertEqual(lookup.segments.first?.fromCode, "RGN")
        XCTAssertEqual(lookup.passengers.count, 1)
    }

    func testTheSearchedAddressStandsInForABookingWithNoContact() throws {
        let lookup = GuestBookingLookup.fromJson(
            try json(#"{"booking": {"reference": "EW-1", "status": "held"}}"#),
            contactEmail: "typed@gmail.com"
        )

        XCTAssertEqual(
            lookup.booking?.contactEmail,
            "typed@gmail.com",
            "the pair that matched is the pair to pay with"
        )
    }

    func testABookingAlreadyCarryingAContactKeepsIt() throws {
        let lookup = GuestBookingLookup.fromJson(
            try json(#"{"booking": {"reference": "EW-1", "contactEmail": "real@gmail.com"}}"#),
            contactEmail: "typed@gmail.com"
        )

        XCTAssertEqual(lookup.booking?.contactEmail, "real@gmail.com")
    }

    func testCollectionsAreReadWhetherWrappedBareOrSingular() throws {
        let wrapped = GuestBookingLookup.fromJson(try json(#"""
        {
          "booking": {"reference": "EW-1"},
          "segments": {
            "bookingSegments": [
              {"fromCode": "RGN"},
              {"fromCode": "BKK"}
            ]
          },
          "passengers": {"firstName": "Solo"}
        }
        """#))

        XCTAssertEqual(wrapped.segments.count, 2)
        XCTAssertEqual(wrapped.passengers.count, 1)
    }

    func testAnEmptyAnswerIsNotMistakenForABooking() throws {
        let empty = GuestBookingLookup.fromJson(
            try json(#"{"ok": true, "booking": {}, "segments": [], "passengers": []}"#)
        )

        XCTAssertNil(empty.booking)
        XCTAssertTrue(empty.segments.isEmpty)
    }

    // MARK: - listGuestBookings refresh

    func testTheServerOwnsStatusMoneyAndTheAirlineReference() throws {
        let merged = mergeGuestBookings(
            [stored("EW-1")],
            [
                GuestBookingSummary.fromJson(try json(#"""
                {
                  "reference": "EW-1",
                  "status": "ticketed",
                  "route": "RGN → SIN",
                  "total": 500,
                  "currency": "MMK",
                  "pnr": "17RJ5B",
                  "ticketed": true,
                  "ticketTimeLimit": "2026-09-04T10:00:00.000Z"
                }
                """#)),
            ]
        )

        let record = try XCTUnwrap(merged.first)
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(record.status, GuestBookingStatus.confirmed)
        XCTAssertEqual(record.pnr, "17RJ5B")
        XCTAssertEqual(record.amount, 500)
        XCTAssertEqual(record.route, "RGN → SIN")
        XCTAssertEqual(record.ticketTimeLimit?.toUtc(), DateTime.utc(2026, 9, 4, 10))
    }

    func testABookingTheAnswerSkipsIsKeptAsItWas() throws {
        let merged = mergeGuestBookings(
            [stored("EW-1", pnr: "ABC"), stored("EW-2")],
            [
                GuestBookingSummary.fromJson(try json(#"{"reference": "EW-2", "status": "cancelled"}"#)),
            ]
        )

        XCTAssertEqual(merged.first?.reference, "EW-1")
        XCTAssertEqual(merged.first?.status, GuestBookingStatus.pendingPayment)
        XCTAssertEqual(merged.first?.pnr, "ABC")
        XCTAssertEqual(merged.last?.status, GuestBookingStatus.cancelled)
    }

    func testAnEmptyAnswerChangesNothing() {
        let records = [stored("EW-1")]
        XCTAssertEqual(mergeGuestBookings(records, []), records)
    }

    func testReferencesMatchRegardlessOfCase() throws {
        let merged = mergeGuestBookings(
            [stored("ew-1")],
            [
                GuestBookingSummary.fromJson(try json(#"{"reference": "EW-1", "status": "held", "pnr": "XYZ"}"#)),
            ]
        )

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.pnr, "XYZ")
    }
}
