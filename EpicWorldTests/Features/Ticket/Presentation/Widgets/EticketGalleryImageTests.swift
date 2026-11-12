// Port of test/features/ticket/presentation/widgets/eticket_gallery_image_test.dart
import XCTest
@testable import EpicWorld

final class EticketGalleryImageTests: XCTestCase {
    private let baseTicket = TicketMockService().getTickets(DateTime(2026, 8, 5)).first!

    private func ticket(id: String, bookingReference: String) -> TicketModel {
        TicketModel(
            id: id,
            bookingReference: bookingReference,
            outbound: baseTicket.outbound,
            inbound: baseTicket.inbound,
            passengerName: baseTicket.passengerName,
            seatCount: baseTicket.seatCount,
            totalPaid: baseTicket.totalPaid,
            currency: baseTicket.currency,
            issuedAt: baseTicket.issuedAt,
            qrPayload: baseTicket.qrPayload
        )
    }

    func testUsesAGallerySafeETicketFilename() {
        XCTAssertEqual(
            ETicketGalleryImage.fileName(ticket(id: "ticket-1", bookingReference: "EW / 1042?")),
            "epic_world_eticket_EW___1042_"
        )
    }

    func testUsesTheTicketIdWhenNoBookingReferenceIsAvailable() {
        XCTAssertEqual(
            ETicketGalleryImage.fileName(ticket(id: "ticket/42", bookingReference: "")),
            "epic_world_eticket_ticket_42"
        )
    }
}
