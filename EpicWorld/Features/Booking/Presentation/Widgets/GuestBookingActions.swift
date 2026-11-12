// Port of lib/features/booking/presentation/widgets/guest_booking_actions.dart
import SwiftUI

/// Re-opens a guest's held booking at the reservation confirmation.
///
/// One path for both ways in — the "Pay now" button on a device history card
/// and the reference/email form on "Find my booking" — because they differ only
/// in where the pair comes from. The server is always asked: a card can be
/// hours old, and only `findGuestBooking` knows whether the hold is still
/// alive and what is actually owed.
///
/// Returns nil once the confirmation screen is open, or a message to show the
/// customer when it could not be. Whatever the outcome, the stored copy of the
/// booking is brought up to date, so a hold that has since been paid or
/// released stops offering to be paid for.
///
/// Dart takes `(BuildContext context, WidgetRef ref)`; here the container and
/// router stand in for them, and `isMounted` is the caller's
/// `context.mounted` (the screen that started the lookup may be gone by the
/// time the server answers).
@MainActor
@discardableResult
func openGuestBooking(
    _ container: AppContainer,
    _ router: AppRouter,
    reference: String,
    email: String,
    isMounted: () -> Bool = { true }
) async -> String? {
    let result = await container.loadGuestBookingCheckoutUseCase((reference: reference, email: email))

    if let record = result.record { await GuestBookingStore.save(record) }
    if !isMounted() { return nil }
    container.deviceGuestBookings.invalidate()

    guard let checkout = result.checkout else {
        return result.error ?? "This booking could not be opened."
    }

    let resume = checkout.resume
    // Riverpod (use case, guest bookings above) and BLoC (the flow below) side
    // by side in Dart; here both live on the container.
    container.flightBookingBloc.add(
        .heldBookingResumed(
            from: resume.from,
            to: resume.to,
            departDate: resume.departDate,
            adults: resume.adults,
            children: resume.children,
            infants: resume.infants,
            cabinClass: resume.cabinClass,
            outbound: resume.outbound,
            inbound: resume.inbound,
            holdRequest: resume.holdRequest,
            holdResponse: resume.holdResponse,
            // A guest arriving from a reference has not seen this booking since
            // they made it, so the reservation is shown first and they choose to
            // continue to payment from there.
            stage: .confirmation
        )
    )

    // Not awaited: the checkout leaves by replacing the stack once it is paid
    // for, so this route may never return. Awaiting it would leave the button
    // that started it spinning for the rest of the session.
    router.push(.bookingDetail)
    return nil
}
