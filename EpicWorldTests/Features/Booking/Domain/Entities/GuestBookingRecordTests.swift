import XCTest
@testable import EpicWorld

/// Port of test/features/booking/domain/entities/guest_booking_record_test.dart.
final class GuestBookingRecordTests: XCTestCase {
    private func record(
        status: String = GuestBookingStatus.pendingPayment,
        ticketTimeLimit: DateTime? = nil
    ) -> GuestBookingRecord {
        GuestBookingRecord(
            reference: "EW-8F4PHA",
            email: "sjbudv0wrv@gmail.com",
            route: "RGN → BKK",
            service: "flight",
            travelDate: "2026-09-06",
            savedAt: DateTime.utc(2026, 9, 3, 9, 6, 38),
            ticketTimeLimit: ticketTimeLimit,
            amount: 412641,
            currency: "MMK",
            status: status
        )
    }

    func testRoundTripsThroughTheShapeStoredOnTheDevice() {
        let original = record(ticketTimeLimit: DateTime.utc(2026, 9, 3, 17, 0)).copyWith(pnr: "17RJ5B")
        let json = original.toJson()

        XCTAssertEqual(Dart.str(json["reference"]), "EW-8F4PHA")
        XCTAssertEqual(Dart.str(json["email"]), "sjbudv0wrv@gmail.com")
        XCTAssertEqual(Dart.str(json["route"]), "RGN → BKK")
        XCTAssertEqual(Dart.str(json["service"]), "flight")
        XCTAssertEqual(Dart.str(json["travelDate"]), "2026-09-06")
        XCTAssertEqual(Dart.str(json["savedAt"]), "2026-09-03T09:06:38.000Z")
        XCTAssertEqual(Dart.str(json["ticketTimeLimit"]), "2026-09-03T17:00:00.000Z")
        XCTAssertEqual(Dart.double(json["amount"]), 412641)
        XCTAssertEqual(Dart.str(json["currency"]), "MMK")
        XCTAssertEqual(Dart.str(json["status"]), "pending_payment")

        let restored = GuestBookingRecord.fromJson(json)
        XCTAssertEqual(restored.reference, original.reference)
        XCTAssertEqual(restored.email, original.email)
        XCTAssertEqual(restored.amount, original.amount)
        XCTAssertEqual(restored.pnr, "17RJ5B")
        XCTAssertEqual(
            restored.ticketTimeLimit?.toUtc(),
            DateTime.utc(2026, 9, 3, 17, 0),
            "the deadline must survive the local/UTC round trip"
        )
    }

    func testARecordMissingItsOptionalFieldsStillReadsBack() {
        let restored = GuestBookingRecord.fromJson([
            "reference": "EW-2SHQQM",
            "email": "k@gmail.com",
        ])

        XCTAssertEqual(restored.status, GuestBookingStatus.pendingPayment)
        XCTAssertEqual(restored.currency, "MMK")
        XCTAssertNil(restored.ticketTimeLimit)
        XCTAssertNil(restored.timeLeft)
        XCTAssertEqual(restored.amount, 0)
    }

    func testTheAddressIsMaskedASharedDeviceMustNotShowItInFull() {
        XCTAssertEqual(record().maskedEmail, "s•••••@gmail.com")
        XCTAssertEqual(
            GuestBookingRecord.fromJson([
                "reference": "EW-1",
                "email": "not-an-address",
            ]).maskedEmail,
            "not-an-address",
            "nothing to mask around, so nothing is invented"
        )
    }

    // MARK: - payability

    func testAHoldWithTimeLeftCanStillBePaid() {
        let record = self.record(ticketTimeLimit: DateTime.now().add(Duration(hours: 7)))
        XCTAssertTrue(record.isPayable)
        XCTAssertFalse(record.isExpired)
        XCTAssertEqual(record.timeLeft?.inHours, 6)
    }

    func testALapsedDeadlineStopsOfferingPayment() {
        let record = self.record(ticketTimeLimit: DateTime.now().subtract(Duration(minutes: 1)))
        XCTAssertEqual(record.timeLeft, Duration.zero)
        XCTAssertTrue(record.isExpired)
        XCTAssertFalse(record.isPayable)
    }

    func testAPaidBookingIsNeitherPendingNorPayable() {
        let record = self.record(
            status: GuestBookingStatus.confirmed,
            ticketTimeLimit: DateTime.now().add(Duration(hours: 7))
        )
        XCTAssertFalse(record.isPendingPayment)
        XCTAssertFalse(record.isPayable)
        XCTAssertEqual(GuestBookingStatus.label(record), "Confirmed")
    }

    func testServerStatusesFoldIntoTheAppVocabulary() {
        XCTAssertEqual(GuestBookingStatus.fromServer("held"), "pending_payment")
        XCTAssertEqual(GuestBookingStatus.fromServer("Ticketed"), "confirmed")
        XCTAssertEqual(GuestBookingStatus.fromServer("held", ticketed: true), "confirmed")
        XCTAssertEqual(GuestBookingStatus.fromServer("CANCELLED"), "cancelled")
        XCTAssertEqual(GuestBookingStatus.fromServer("expired"), "expired")
        XCTAssertEqual(
            GuestBookingStatus.fromServer("something new"),
            "pending_payment",
            "an unknown status must not silently retire a live hold"
        )
    }
}
