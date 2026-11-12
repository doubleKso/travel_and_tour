// Port of lib/features/booking/presentation/providers/booking_providers.dart

import Foundation
import Observation

/// Riverpod's `ref.watch(provider.select((s) => …))`: an observable value that
/// changes only when the selected value does.
///
/// `AsyncResource` reloads whenever anything its `dependencies` closure reads
/// changes. Reading `authNotifier.state` or `flightBookingBloc.state` there
/// directly would reload on *every* auth or booking change (a token rotation,
/// each bloc emission); reading one of these instead narrows it to the field
/// the Dart provider selected. (Kept local: the foundation has no `select`.)
@MainActor
@Observable
fileprivate final class BookingSelection<Value: Equatable> {
    private(set) var value: Value
    @ObservationIgnored private let read: () -> Value

    init(_ read: @escaping () -> Value) {
        self.read = read
        self.value = read()
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

/// Dart record `(id: state.user?.id ?? '', email: state.user?.email ?? '')`.
fileprivate struct BookingSessionIdentity: Hashable {
    let id: String
    let email: String
}

extension AppContainer {
    // MARK: - Selections (the `.select(...)` parts of the Dart providers)

    /// `authNotifierProvider.select((state) => state.user?.id)`.
    fileprivate var bookingSessionUserId: BookingSelection<String?> {
        provide { BookingSelection { [unowned self] in self.authNotifier.state.user?.id } }
    }

    /// `authNotifierProvider.select((state) => (id: …, email: …))`.
    fileprivate var bookingSessionIdentity: BookingSelection<BookingSessionIdentity> {
        provide {
            BookingSelection { [unowned self] in
                BookingSessionIdentity(
                    id: self.authNotifier.state.user?.id ?? "",
                    email: self.authNotifier.state.user?.email ?? ""
                )
            }
        }
    }

    /// `flightBookingStateProvider.select((state) => state.scope)`.
    fileprivate var bookingSearchScope: BookingSelection<TravelScope> {
        provide { BookingSelection { [unowned self] in self.flightBookingBloc.state.scope } }
    }

    /// What `_withOptionalSession` watches.
    fileprivate var bookingSessionDependency: AnyHashable {
        AnyHashable(bookingSessionUserId.value)
    }

    /// Runs public catalogue calls as a guest or with a transparently renewed
    /// member session. Watch identity only: rotating a token must not restart
    /// the request that triggered the rotation.
    ///
    /// Dart `_withOptionalSession(ref, request)`; the identity watch is the
    /// `dependencies:` closure of each resource below.
    fileprivate func withOptionalSession<T>(_ request: @escaping (String?) async throws -> T) async throws -> T {
        try await authNotifier.withValidAccessToken { token in
            try await request(token.isEmpty ? nil : token)
        }
    }

    /// A catalogue `FutureProvider` body: `_withOptionalSession` plus the
    /// session-identity watch.
    fileprivate func optionalSessionResource<T>(
        _ request: @escaping (String?) async throws -> T
    ) -> AsyncResource<T> {
        AsyncResource(dependencies: { [unowned self] in self.bookingSessionDependency }) { [unowned self] in
            try await self.withOptionalSession(request)
        }
    }

    // MARK: - Providers

    /// Public flight reference data is loaded for both guests and signed-in users.
    /// A token change (login, logout, or restoration) refreshes the catalogue.
    var activeAirportList: AsyncResource<[AirportModel]> {
        provide {
            let service = flightCatalogueRemoteService
            return optionalSessionResource { token in try await service.getActiveAirports(accessToken: token) }
        }
    }

    var activeCountryList: AsyncResource<[AirportCountryModel]> {
        provide {
            let service = flightCatalogueRemoteService
            return optionalSessionResource { token in try await service.getActiveCountries(accessToken: token) }
        }
    }

    var activeAirportCityList: AsyncResource<[AirportCityModel]> {
        provide {
            let service = flightCatalogueRemoteService
            return optionalSessionResource { token in try await service.getActiveAirportCities(accessToken: token) }
        }
    }

    var activeFlightCarrierList: AsyncResource<[FlightCarrierModel]> {
        provide {
            let service = flightCatalogueRemoteService
            return optionalSessionResource { token in try await service.getActiveCarriers(accessToken: token) }
        }
    }

    var activeFlightScheduleList: AsyncResource<[FlightScheduleModel]> {
        provide {
            let service = flightCatalogueRemoteService
            return optionalSessionResource { token in try await service.getActiveFlightSchedules(accessToken: token) }
        }
    }

    var globalAirlineRateList: AsyncResource<[GlobalAirlineRateModel]> {
        provide {
            let service = flightCatalogueRemoteService
            return optionalSessionResource { token in try await service.getGlobalAirlineRates(accessToken: token) }
        }
    }

    var tierAirlineRateList: AsyncResource<[TierAirlineRateModel]> {
        provide {
            let service = flightCatalogueRemoteService
            return optionalSessionResource { token in try await service.getTierAirlineRates(accessToken: token) }
        }
    }

    var activeTierBenefitList: AsyncResource<[TierBenefitModel]> {
        provide {
            let service = flightCatalogueRemoteService
            return optionalSessionResource { token in try await service.getActiveTierBenefits(accessToken: token) }
        }
    }

    /// State/division codes for the Myanmar NRC selector. This catalogue is public
    /// but refreshes after sign-in so the current session is included when present.
    var nrcCodeList: AsyncResource<[NrcCode]> {
        provide {
            let service = nrcRemoteService
            return optionalSessionResource { token in try await service.getNrcCodes(accessToken: token) }
        }
    }

    /// Townships are scoped to the selected NRC code and load only after a code is
    /// chosen in the traveller form. Read as `container.nrcTownshipList(code).state`.
    var nrcTownshipList: AsyncResourceFamily<String, [NrcTownship]> {
        provide {
            let service = nrcRemoteService
            return AsyncResourceFamily(
                dependencies: { [unowned self] _ in self.bookingSessionDependency }
            ) { [unowned self] nrcCode in
                try await self.withOptionalSession { token in
                    try await service.getNrcTownships(nrcCode: nrcCode, accessToken: token)
                }
            }
        }
    }

    // The live booking flow itself is a bloc, not a provider — see
    // `Presentation/Bloc/FlightBookingBridge.swift`.

    /// The current customer's non-MAI airline enquiries, shown in travel history.
    var myServiceEnquiries: AsyncResource<[ServiceEnquiryModel]> {
        provide {
            // Watched on identity, not on the token: renewing a token below must not
            // restart the very fetch that is already using the renewed one.
            AsyncResource(
                dependencies: { [unowned self] in AnyHashable(self.bookingSessionIdentity.value) }
            ) { [unowned self] in
                let user = self.bookingSessionIdentity.value
                if user.id.isEmpty || user.email.isEmpty { return [] }
                // The repository runs this through the shared session wrapper, including a
                // refresh + retry when the backend rejects the first token.
                let result = await self.getMyServiceEnquiriesUseCase((userId: user.id, email: user.email))
                switch result {
                case .failure(let failure): throw StateError(failure.message)
                case .success(let enquiries): return enquiries
                }
            }
        }
    }

    /// Airport cities for the From–To picker. `ListActiveAirportCities` returns
    /// both types in one response, so filter its `isDomestic` / `isInternational`
    /// flags against the scope currently selected on the search form.
    ///
    /// That scope lives in the flight-booking bloc, so this is the bloc → provider
    /// direction of the old bridge: it watches the bloc's state.
    var locationList: AsyncResource<[LocationModel]> {
        provide {
            AsyncResource(
                dependencies: { [unowned self] in
                    // `ref.watch(activeAirportCityListProvider.future)`: a reload of the
                    // city list reloads this too.
                    _ = self.activeAirportCityList.peek.isLoading
                    return AnyHashable(self.bookingSearchScope.value)
                }
            ) { [unowned self] in
                let scope = self.bookingSearchScope.value
                let cities = try await self.activeAirportCityList.future
                let domestic = scope == .domestic
                return cities
                    .filter { $0.isAvailableFor(domestic: domestic) }
                    .map { city in
                        LocationModel(
                            code: city.code,
                            city: city.name,
                            facilityName: city.name,
                            country: city.country,
                            searchCode: city.code
                        )
                    }
            }
        }
    }

    /// The bookings this device remembers from guest checkouts, refreshed against
    /// `listGuestBookings` so the cards show the server's status rather than
    /// whatever was true when the seats were held.
    ///
    /// A failed refresh is not an error state: the stored rows are still the best
    /// answer available, and one of them is how the customer gets back to a
    /// booking they have not paid for yet.
    var deviceGuestBookings: AsyncResource<[GuestBookingRecord]> {
        provide {
            AsyncResource { [unowned self] in
                let stored = await GuestBookingStore.read()
                if stored.isEmpty { return [] }
                do {
                    let latest = try await self.guestBookingCallableService.listGuestBookings(
                        stored.map { (reference: $0.reference, email: $0.email) }
                    )
                    if latest.isEmpty { return stored }
                    let merged = mergeGuestBookings(stored, latest)
                    await GuestBookingStore.replaceAll(merged)
                    return merged
                } catch {
                    return stored
                }
            }
        }
    }
}
