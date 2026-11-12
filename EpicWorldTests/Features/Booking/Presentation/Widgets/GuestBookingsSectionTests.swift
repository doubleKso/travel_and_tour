import SwiftUI
import XCTest
@testable import EpicWorld

/// Ports the logic of
/// test/features/booking/presentation/widgets/guest_bookings_section_test.dart:
/// each card's meta line, countdown and status chip. The status labels and the
/// masked address belong to `GuestBookingRecord` / `GuestBookingStatus` (the
/// domain port); the dismiss-forgets-the-booking step needs the keychain-backed
/// `GuestBookingStore` and is left to the data port's tests.
/// guest_bookings_empty_test.dart asserts widgets only and is not ported.
@MainActor
final class GuestBookingsSectionTests: XCTestCase {
    private typealias Section = DeviceBookingsSection<EmptyView>

    private func record(
        reference: String,
        status: String = GuestBookingStatus.pendingPayment,
        left: Duration = Duration(hours: 7, minutes: 44),
        pnr: String = "17RJ5B",
        travelDate: String = "2026-09-06"
    ) -> GuestBookingRecord {
        GuestBookingRecord(
            reference: reference,
            email: "sjbudv0wrv@gmail.com",
            route: "RGN → BKK",
            service: "flight",
            travelDate: travelDate,
            savedAt: DateTime.now(),
            ticketTimeLimit: DateTime.now().add(left),
            amount: 381_582,
            currency: "MMK",
            status: status,
            pnr: pnr
        )
    }

    func testTheMetaLineQuotesBothReferencesAndTheTravelDay() {
        // The reference and the airline's own, so either can be quoted.
        XCTAssertEqual(
            Section.metaLine(record(reference: "EW-8F4PHA")),
            "EW-8F4PHA  ·  Airline ref 17RJ5B  ·  6 Sep 2026"
        )
    }

    func testTheMetaLineSkipsWhatIsUnknown() {
        XCTAssertEqual(Section.metaLine(record(reference: "EW-PAID11", pnr: "", travelDate: "")), "EW-PAID11")
        XCTAssertEqual(
            Section.metaLine(record(reference: "EW-LAPSED", pnr: "", travelDate: "2026-09-06")),
            "EW-LAPSED  ·  6 Sep 2026"
        )
    }

    func testTheCountdownRendersToTheMinute() {
        XCTAssertEqual(Section.timeLeftLabel(Duration(hours: 7, minutes: 44)), "7h 44m left")
        XCTAssertEqual(Section.timeLeftLabel(Duration(days: 1, hours: 2, minutes: 3)), "1d 2h 3m left")
        XCTAssertEqual(Section.timeLeftLabel(Duration(minutes: 5)), "5m left")
    }

    func testEachChipSaysWhereItsBookingStands() {
        let held = Section.statusChipColors(record(reference: "EW-8F4PHA"))
        XCTAssertEqual(held.background, Color(0xFFFFEBC0))
        XCTAssertEqual(held.foreground, Color(0xFFA76B00))

        let confirmed = Section.statusChipColors(
            record(reference: "EW-PAID11", status: GuestBookingStatus.confirmed)
        )
        XCTAssertEqual(confirmed.background, AppColors.primarySurface)
        XCTAssertEqual(confirmed.foreground, AppColors.primaryDark)

        let cancelled = Section.statusChipColors(
            record(reference: "EW-VOID01", status: GuestBookingStatus.cancelled)
        )
        XCTAssertEqual(cancelled.background, Color(0xFFFBE6E3))
        XCTAssertEqual(cancelled.foreground, AppColors.error)

        let lapsed = Section.statusChipColors(
            record(reference: "EW-LAPSED", left: Duration(seconds: -1))
        )
        XCTAssertEqual(lapsed.background, AppColors.divider)
        XCTAssertEqual(lapsed.foreground, AppColors.textSecondary)
    }
}
