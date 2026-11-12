// Port of lib/features/ticket/presentation/providers/booking_history_providers.dart
import Foundation
import Observation

extension AppContainer {
    /// History is private to the signed-in customer. It refreshes automatically
    /// when their account changes.
    ///
    /// Watched on the customer's identity, not on their token, and the token is
    /// renewed here instead. History is a screen customers open after leaving the
    /// app alone, so `state.user.token` is exactly the token most likely to come
    /// back as "Access token expired" — and watching the token as well would
    /// restart this fetch every time a renewal landed.
    ///
    /// `myBookingHistoryProvider`.
    var myBookingHistory: AsyncResource<[BookingHistoryItem]> {
        provide {
            // Create the selection here, outside the resource's observation
            // scope, so only its `value` is what the resource watches.
            _ = bookingHistoryIdentity
            return AsyncResource(
                // ref.watch(authNotifierProvider.select((s) => (id, email)))
                dependencies: { [unowned self] in AnyHashable(self.bookingHistoryIdentity.value) }
            ) { [unowned self] in
                let userId = self.authNotifier.state.user?.id ?? ""
                let email = self.authNotifier.state.user?.email ?? ""
                if userId.isEmpty || email.isEmpty { return [] }
                let service = self.bookingHistoryRemoteService
                return try await self.authNotifier.withValidAccessToken { token in
                    try await service.getMyBookings(
                        userId: userId,
                        email: email,
                        accessToken: token
                    )
                }
            }
        }
    }

    /// `myBookingHistoryDetailProvider` — the flight segments and travellers of
    /// one booking, fetched together.
    var myBookingHistoryDetail: AsyncResourceFamily<String, BookingHistoryDetail> {
        provide {
            _ = bookingHistoryUserId
            return AsyncResourceFamily(
                // ref.watch(authNotifierProvider.select((s) => s.user?.id ?? ''))
                dependencies: { [unowned self] _ in AnyHashable(self.bookingHistoryUserId.value) }
            ) { [unowned self] bookingId in
                let service = self.bookingHistoryRemoteService
                return try await self.authNotifier.withValidAccessToken { token in
                    // Future.wait([...]): both lookups run concurrently.
                    async let segments = service.getMyBookingSegments(
                        bookingId: bookingId,
                        accessToken: token
                    )
                    async let passengers = service.getMyBookingPassengers(
                        bookingId: bookingId,
                        accessToken: token
                    )
                    return BookingHistoryDetail(
                        segments: try await segments,
                        passengers: try await passengers
                    )
                }
            }
        }
    }

    /// `authNotifierProvider.select((state) => (id: …, email: …))`.
    private var bookingHistoryIdentity: ProviderSelection<[String]> {
        provide {
            ProviderSelection { [unowned self] in
                [self.authNotifier.state.user?.id ?? "", self.authNotifier.state.user?.email ?? ""]
            }
        }
    }

    /// `authNotifierProvider.select((state) => state.user?.id ?? '')`.
    private var bookingHistoryUserId: ProviderSelection<String> {
        provide {
            ProviderSelection { [unowned self] in self.authNotifier.state.user?.id ?? "" }
        }
    }
}

/// Riverpod's `provider.select(…)`: an observable value that changes only when
/// the selected part of its source does. A resource whose `dependencies` read
/// `value` therefore reloads on a change of identity, not on every change of
/// the auth state (a token renewal, a loading flag). The foundation's
/// `AsyncResource` reloads on any change to what it reads, so the selection is
/// made here.
@MainActor
@Observable
private final class ProviderSelection<Value: Equatable> {
    private(set) var value: Value
    private let read: () -> Value

    init(_ read: @escaping () -> Value) {
        self.read = read
        value = read()
        track()
    }

    private func track() {
        withObservationTracking {
            _ = read()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let next = self.read()
                if next != self.value { self.value = next }
                self.track()
            }
        }
    }
}
