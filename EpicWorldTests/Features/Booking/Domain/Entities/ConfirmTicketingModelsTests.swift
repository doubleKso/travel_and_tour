import XCTest
@testable import EpicWorld

/// Port of test/features/booking/domain/entities/confirm_ticketing_models_test.dart.
final class ConfirmTicketingModelsTests: XCTestCase {
    func testSerializesTheConfirmTicketingCallableRequest() {
        let request = ConfirmTicketingRequest(
            reference: "EW-V92BJV",
            email: "traveller@example.com",
            accessToken: "session-access-token"
        )

        XCTAssertEqual(
            NSDictionary(dictionary: request.toJson()),
            NSDictionary(dictionary: [
                "reference": "EW-V92BJV",
                "email": "traveller@example.com",
                "accessToken": "session-access-token",
            ])
        )
    }

    func testAllowsAGuestTicketConfirmationWithoutAnAccessToken() {
        let holdRequest = FlightHoldRequest(
            selections: [],
            passengers: [],
            contact: ["email": " guest@example.com "]
        )
        let request = ConfirmTicketingRequest.fromHeldBooking(
            reference: "EW-GUEST1",
            holdRequest: holdRequest,
            accessToken: "   "
        )

        XCTAssertEqual(
            NSDictionary(dictionary: request.toJson()),
            NSDictionary(dictionary: [
                "reference": "EW-GUEST1",
                "email": "guest@example.com",
                "accessToken": NSNull(),
            ])
        )
    }

    func testMapsASuccessfulConfirmTicketingResponse() throws {
        let response = ConfirmTicketingResponse.fromJson(try json(#"""
        {
          "ok": true,
          "ticketed": true,
          "reason": "",
          "message": "Ticket confirmed",
          "tickets": [
            {"number": "2171234567890", "passenger": "Traveller One"}
          ]
        }
        """#))

        XCTAssertTrue(response.ok)
        XCTAssertTrue(response.ticketed)
        XCTAssertEqual(response.message, "Ticket confirmed")
        XCTAssertEqual(response.tickets.count, 1)
        XCTAssertEqual(response.tickets.first?.number, "2171234567890")
        XCTAssertEqual(response.tickets.first?.passenger, "Traveller One")
    }

    private func json(_ text: String) throws -> JSON {
        try XCTUnwrap(Dart.map(try jsonDecode(text)))
    }
}
