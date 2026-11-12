// Port of lib/features/booking/domain/entities/guest_booking_checkout.dart

import Foundation

/// A guest booking fetched by reference and turned back into a checkout.
///
/// `resume` is what the flight-booking bloc's `heldBookingResumed` event needs
/// to redraw the reservation; `record` is the same booking in the shape this
/// device stores, so a lookup doubles as a refresh of the history card that
/// started it.
///
/// Built by `LoadGuestBookingCheckoutUseCase`.
struct GuestBookingCheckout {
    let resume: HeldBookingResume
    let record: GuestBookingRecord

    init(resume: HeldBookingResume, record: GuestBookingRecord) {
        self.resume = resume
        self.record = record
    }

    /// The device-storage view of a booking the server just described.
    static func recordFrom(
        _ booking: BookingHistoryItem,
        email: String,
        travelDate: String = ""
    ) -> GuestBookingRecord {
        let contactEmail = booking.contactEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        return GuestBookingRecord(
            reference: booking.reference,
            email: !contactEmail.isEmpty ? contactEmail : email,
            route: booking.route,
            service: !booking.service.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? booking.service
                : "flight",
            travelDate: travelDate.trimmingCharacters(in: .whitespacesAndNewlines),
            savedAt: DateTime.now(),
            ticketTimeLimit: booking.ticketTimeLimit,
            amount: booking.total,
            currency: booking.currency,
            status: GuestBookingStatus.fromServer(booking.status),
            pnr: booking.pnr
        )
    }
}
