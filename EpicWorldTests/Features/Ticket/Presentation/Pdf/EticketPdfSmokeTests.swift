// Port of test/features/ticket/presentation/pdf/eticket_pdf_smoke_test.dart
import XCTest
@testable import EpicWorld

/// Smoke test: the e-ticket PDF must build for both a round-trip and a one-way
/// ticket without failing, and produce a non-trivial document.
final class EticketPdfSmokeTests: XCTestCase {
    @MainActor
    func testETicketPdfBuildRendersEverySampleTicket() async {
        let service = TicketMockService()
        let tickets = service.getTickets(DateTime(2026, 8, 5))
        XCTAssertFalse(tickets.isEmpty)
        for t in tickets {
            let bytes = await ETicketPdf.build(t)
            XCTAssertGreaterThan(bytes.count, 2000, "PDF for \(t.bookingReference) looks empty")
            XCTAssertTrue(bytes.starts(with: Data("%PDF".utf8)), "PDF for \(t.bookingReference) is not a PDF")
        }
    }

    func testFileNamePrefersTheBookingReference() {
        let ticket = TicketMockService().getTickets(DateTime(2026, 8, 5)).first!
        XCTAssertEqual(ETicketPdf.fileName(ticket), "eticket_\(ticket.bookingReference).pdf")
    }
}
