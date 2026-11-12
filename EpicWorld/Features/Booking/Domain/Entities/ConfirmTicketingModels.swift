// Port of lib/features/booking/domain/entities/confirm_ticketing_models.dart

import Foundation

/// Request sent to the `confirmTicketing` callable.
///
/// Guest bookings are confirmed by reference and contact email. Signed-in
/// customers additionally send their access token so the booking is associated
/// with their account.
struct ConfirmTicketingRequest: Hashable {
    let reference: String
    let email: String
    let accessToken: String?

    init(reference: String, email: String, accessToken: String? = nil) {
        self.reference = reference
        self.email = email
        self.accessToken = accessToken
    }

    /// Builds the confirmation payload from the exact contact information that
    /// was submitted when the seats were held. Empty tokens are normalized to
    /// null so guest checkout uses the public confirmation contract.
    static func fromHeldBooking(
        reference: String,
        holdRequest: FlightHoldRequest,
        accessToken: String? = nil
    ) -> ConfirmTicketingRequest {
        let token = accessToken?.trimmingCharacters(in: .whitespacesAndNewlines)
        return ConfirmTicketingRequest(
            reference: reference.trimmingCharacters(in: .whitespacesAndNewlines),
            email: Dart.str(holdRequest.contact["email"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            accessToken: token == nil || token!.isEmpty ? nil : token
        )
    }

    func toJson() -> JSON {
        [
            "reference": reference,
            "email": email,
            "accessToken": (accessToken as Any?) ?? NSNull(),
        ]
    }
}

/// One issued ticket returned by `confirmTicketing`.
struct ConfirmedTicket: Hashable {
    let number: String
    let passenger: String

    init(number: String, passenger: String) {
        self.number = number
        self.passenger = passenger
    }

    static func fromJson(_ json: JSON) -> ConfirmedTicket {
        ConfirmedTicket(
            number: Dart.str(json["number"]) ?? "",
            passenger: Dart.str(json["passenger"]) ?? ""
        )
    }
}

/// Result returned after the airline ticketing attempt.
struct ConfirmTicketingResponse: Hashable {
    let ok: Bool
    let ticketed: Bool
    let reason: String
    let message: String
    let tickets: [ConfirmedTicket]

    init(ok: Bool, ticketed: Bool, reason: String, message: String, tickets: [ConfirmedTicket]) {
        self.ok = ok
        self.ticketed = ticketed
        self.reason = reason
        self.message = message
        self.tickets = tickets
    }

    static func fromJson(_ json: JSON) -> ConfirmTicketingResponse {
        ConfirmTicketingResponse(
            ok: Dart.bool(json["ok"]) == true,
            ticketed: Dart.bool(json["ticketed"]) == true,
            reason: Dart.str(json["reason"]) ?? "",
            message: Dart.str(json["message"]) ?? "",
            tickets: Dart.maps(json["tickets"]).map { ConfirmedTicket.fromJson($0) }
        )
    }
}
