// Port of lib/features/booking/data/repositories/guest_booking_repository_impl.dart

import Foundation

final class GuestBookingRepositoryImpl: GuestBookingRepository {
    private let remote: GuestBookingCallableService

    init(_ remote: GuestBookingCallableService) {
        self.remote = remote
    }

    func findGuestBooking(reference: String, email: String) async -> AppResult<GuestBookingLookup> {
        do {
            return .success(try await remote.findGuestBooking(reference: reference, email: email))
        } catch {
            // The lookup screen shows the backend's own wording for every failure,
            // offline included, so keep `messageFrom`'s text rather than mapping an
            // unreachable callable to NetworkFailure's generic one.
            // (Dart catches `on Exception`; every error a data source throws in
            // Swift is one, so all of them land here.)
            return .failure(.server(message: ApiException.messageFrom(error)))
        }
    }
}
