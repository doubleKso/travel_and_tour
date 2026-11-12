// Port of lib/features/visa/presentation/providers/visa_providers.dart

import Foundation
import Observation

extension AppContainer {
    /// Active visa countries, refreshed automatically whenever session state
    /// changes. Guests call the same public operation with a null token.
    var activeVisaCountryList: AsyncResource<[VisaCountryModel]> {
        provide {
            // ref.watch(authNotifierProvider.select((state) => state.user?.id))
            let userId = VisaAuthSelection { [unowned self] in self.authNotifier.state.user?.id }
            return AsyncResource<[VisaCountryModel]>(dependencies: { AnyHashable(userId.value) }) { [unowned self] in
                let service = self.visaRemoteService
                return try await self.authNotifier.withValidAccessToken { token in
                    try await service.getActiveVisaCountries(
                        accessToken: token.isEmpty ? nil : token
                    )
                }
            }
        }
    }

    var publishedVisaTypeCountryList: AsyncResource<[VisaTypeCountryModel]> {
        provide {
            let userId = VisaAuthSelection { [unowned self] in self.authNotifier.state.user?.id }
            return AsyncResource<[VisaTypeCountryModel]>(dependencies: { AnyHashable(userId.value) }) { [unowned self] in
                let service = self.visaRemoteService
                return try await self.authNotifier.withValidAccessToken { token in
                    try await service.getPublishedVisaTypeCountries(
                        accessToken: token.isEmpty ? nil : token
                    )
                }
            }
        }
    }

    /// Destinations that have at least one currently-published visa type.
    var publishedVisaCountryList: AsyncResource<[VisaCountryModel]> {
        provide {
            // ref.watch(activeVisaCountryListProvider.future) and
            // ref.watch(publishedVisaTypeCountryListProvider.future).
            let watched = VisaFutureWatch { [unowned self] in
                [
                    self.activeVisaCountryList.peek.isLoading,
                    self.publishedVisaTypeCountryList.peek.isLoading,
                ]
            }
            return AsyncResource<[VisaCountryModel]>(dependencies: { AnyHashable(watched.generation) }) { [unowned self] in
                let countries = try await self.activeVisaCountryList.future
                let visaTypes = try await self.publishedVisaTypeCountryList.future
                return publishedVisaCountries(countries, visaTypes)
            }
        }
    }

    /// Full profile for one destination, keyed by slug. Nil means the slug is
    /// not in the published catalogue.
    var visaCountryDetail: AsyncResourceFamily<String, VisaCountryDetail?> {
        provide {
            let userId = VisaAuthSelection { [unowned self] in self.authNotifier.state.user?.id }
            return AsyncResourceFamily<String, VisaCountryDetail?>(
                dependencies: { _ in AnyHashable(userId.value) }
            ) { [unowned self] slug in
                let service = self.visaRemoteService
                return try await self.authNotifier.withValidAccessToken { token in
                    try await service.getVisaCountryBySlug(
                        slug: slug,
                        accessToken: token.isEmpty ? nil : token
                    )
                }
            }
        }
    }

    /// Visa types published for one country, keyed by the country ID returned by
    /// `visaCountryDetail`.
    var visaTypeList: AsyncResourceFamily<String, [VisaTypeModel]> {
        provide {
            let userId = VisaAuthSelection { [unowned self] in self.authNotifier.state.user?.id }
            return AsyncResourceFamily<String, [VisaTypeModel]>(
                dependencies: { _ in AnyHashable(userId.value) }
            ) { [unowned self] countryId in
                let service = self.visaRemoteService
                return try await self.authNotifier.withValidAccessToken { token in
                    try await service.getVisaTypes(
                        countryId: countryId,
                        accessToken: token.isEmpty ? nil : token
                    )
                }
            }
        }
    }
}

/// Riverpod's `ref.watch(provider.select(selector))`: an observable value that
/// changes only when the selected value does.
///
/// `AsyncResource` reloads whenever anything its dependency closure reads
/// changes, so reading `authNotifier.state` there directly would also reload
/// on unrelated session changes (a loading flag, a renewed token). Reading
/// this instead reloads only when the signed-in user's id changes, as the
/// Dart `select` does.
@MainActor
@Observable
private final class VisaAuthSelection<Value: Equatable> {
    private(set) var value: Value
    @ObservationIgnored private let selector: () -> Value

    init(_ selector: @escaping () -> Value) {
        self.selector = selector
        value = selector()
        track()
    }

    private func track() {
        let next = withObservationTracking {
            selector()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.track() }
        }
        if next != value { value = next }
    }
}

/// Riverpod's `ref.watch(provider.future)` for a derived `AsyncResource`.
///
/// Riverpod hands out a new future each time the watched provider starts a
/// new load (its own dependencies changed, or it was invalidated) — not when
/// a load completes. `generation` mirrors that: it bumps whenever any watched
/// resource *starts* loading, so the derived resource re-awaits the new
/// futures, and stays put when they finish.
@MainActor
@Observable
private final class VisaFutureWatch {
    private(set) var generation = 0
    @ObservationIgnored private let isLoading: () -> [Bool]
    @ObservationIgnored private var wasLoading: [Bool]

    init(_ isLoading: @escaping () -> [Bool]) {
        self.isLoading = isLoading
        wasLoading = isLoading()
        track()
    }

    private func track() {
        let loading = withObservationTracking {
            isLoading()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.track() }
        }
        if zip(loading, wasLoading).contains(where: { now, before in now && !before }) {
            generation += 1
        }
        wasLoading = loading
    }
}
