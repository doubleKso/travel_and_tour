// Port of lib/features/booking/data/datasources/guest_booking_callable_service.dart

import Foundation

/// Booking lookups for customers who never signed in.
///
/// Both callables authenticate on the reference/email pair itself rather than
/// on a session, which is what lets a guest reach their own reservation — and
/// why nothing here sends an access token.
final class GuestBookingCallableService {
    private let functions: CallableInvoking

    init(_ functions: CallableInvoking) {
        self.functions = functions
    }

    /// Current status for the bookings this device remembers, in one round trip.
    ///
    /// Pairs the server does not recognise are simply absent from the answer;
    /// callers keep what they had rather than treating the gap as a deletion.
    func listGuestBookings(_ pairs: [(reference: String, email: String)]) async throws -> [GuestBookingSummary] {
        let wanted: [JSON] = pairs
            .filter { !$0.reference.isEmpty && !$0.email.isEmpty }
            .map { ["reference": $0.reference, "email": $0.email] }
        if wanted.isEmpty { return [] }

        let response = try await functions.call(
            F.functionsUrl(Endpoints.listGuestBookings),
            ["pairs": wanted] as JSON
        )
        let payload = try ApiException.callablePayload(response, endpoint: Endpoints.listGuestBookings)
        return GuestBookingLookup.list(payload["bookings"]).map { GuestBookingSummary.fromJson($0) }
    }

    /// The whole booking — record, legs and travellers — for one reference.
    ///
    /// This is what the checkout is rebuilt from, so it is asked for only when
    /// the customer is actually going somewhere with it: resuming a payment or
    /// finding a booking by reference.
    func findGuestBooking(reference: String, email: String) async throws -> GuestBookingLookup {
        let response = try await functions.call(
            F.functionsUrl(Endpoints.findGuestBooking),
            [
                "reference": reference.trimmingCharacters(in: .whitespacesAndNewlines),
                "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
            ] as JSON
        )
        let payload = try ApiException.callablePayload(response, endpoint: Endpoints.findGuestBooking)
        return GuestBookingLookup.fromJson(
            payload,
            contactEmail: email.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
