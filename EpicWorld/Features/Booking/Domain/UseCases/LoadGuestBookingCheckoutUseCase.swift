// Port of lib/features/booking/domain/usecases/load_guest_booking_checkout_use_case.dart

import Foundation

/// Looks a guest booking up and, when it can still be paid, rebuilds the
/// checkout.
///
/// Failures come back as a message rather than a `Failure`: every caller shows
/// them the same way, and a mistyped reference is an ordinary outcome of this
/// screen rather than a fault in it. A booking that can no longer be paid still
/// returns its record, so the caller can store the status the server just
/// reported instead of leaving a stale "Pay now" on screen — which is why this
/// returns an outcome record instead of implementing `UseCase`.
final class LoadGuestBookingCheckoutUseCase {
    private let repository: GuestBookingRepository

    init(_ repository: GuestBookingRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: LoadGuestBookingCheckoutParams) async -> GuestBookingCheckoutOutcome {
        let bookingRef = params.reference.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let contactEmail = params.email.trimmingCharacters(in: .whitespacesAndNewlines)
        if bookingRef.isEmpty || contactEmail.isEmpty {
            return (
                checkout: nil,
                record: nil,
                error: "Enter both the booking reference and the email used to book."
            )
        }

        let result = await repository.findGuestBooking(reference: bookingRef, email: contactEmail)
        guard let lookup = result.dataOrNull else {
            return (
                checkout: nil,
                record: nil,
                error: result.failureOrNull!.message
            )
        }

        guard let booking = lookup.booking, !booking.reference.isEmpty else {
            let message = lookup.message.trimmingCharacters(in: .whitespacesAndNewlines)
            return (
                checkout: nil,
                record: nil,
                error: !message.isEmpty ? message : "No booking matches that reference and email."
            )
        }

        let record = GuestBookingCheckout.recordFrom(
            booking,
            email: contactEmail,
            // The itinerary is the only place a departure date lives; the booking
            // record itself carries deadlines, not travel dates.
            travelDate: lookup.segments.isEmpty ? "" : lookup.segments[0].travelDate
        )
        if !booking.isHeld {
            return (
                checkout: nil,
                record: record,
                error: record.status == GuestBookingStatus.confirmed
                    ? "This booking is already paid — check your email for the e-ticket."
                    : "This booking is no longer awaiting payment."
            )
        }

        return (
            checkout: GuestBookingCheckout(
                resume: HeldBookingResume.from(booking, segments: lookup.segments),
                record: record
            ),
            record: record,
            error: nil
        )
    }
}

/// Dart record `({String reference, String email})`.
typealias LoadGuestBookingCheckoutParams = (reference: String, email: String)

/// Dart record `({GuestBookingCheckout? checkout, GuestBookingRecord? record, String? error})`.
typealias GuestBookingCheckoutOutcome = (
    checkout: GuestBookingCheckout?,
    record: GuestBookingRecord?,
    error: String?
)
