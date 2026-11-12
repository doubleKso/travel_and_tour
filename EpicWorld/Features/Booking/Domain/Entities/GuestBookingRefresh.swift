// Port of lib/features/booking/domain/entities/guest_booking_refresh.dart

import Foundation

/// Folds what `listGuestBookings` reports into the records this device stores.
///
/// The server owns status, money and the airline reference; the device owns
/// the pair that identifies the booking and the order the cards appear in. A
/// booking the answer does not mention is kept untouched rather than dropped —
/// a partial answer must not erase what the device knows, and only the
/// customer removes a card.
func mergeGuestBookings(
    _ stored: [GuestBookingRecord],
    _ latest: [GuestBookingSummary]
) -> [GuestBookingRecord] {
    if latest.isEmpty { return stored }
    var byReference: [String: GuestBookingSummary] = [:]
    for summary in latest where !summary.reference.isEmpty {
        byReference[summary.reference.uppercased()] = summary
    }

    return stored.map { record in
        guard let summary = byReference[record.reference.uppercased()] else { return record }
        return record.copyWith(
            route: !summary.route.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? summary.route : nil,
            ticketTimeLimit: summary.ticketTimeLimit,
            amount: summary.total > 0 ? summary.total : nil,
            currency: !summary.currency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? summary.currency
                : nil,
            status: GuestBookingStatus.fromServer(summary.status, ticketed: summary.ticketed),
            pnr: !summary.pnr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? summary.pnr : nil
        )
    }
}
