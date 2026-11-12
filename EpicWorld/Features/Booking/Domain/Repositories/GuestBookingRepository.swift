// Port of lib/features/booking/domain/repositories/guest_booking_repository.dart

import Foundation

/// Guest bookings, found by the reference/email pair from the confirmation
/// email — the only way back to a booking made without an account.
protocol GuestBookingRepository: AnyObject {
    func findGuestBooking(reference: String, email: String) async -> AppResult<GuestBookingLookup>
}
