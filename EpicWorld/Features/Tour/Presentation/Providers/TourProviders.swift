// Port of lib/features/tour/presentation/providers/tour_providers.dart

import Foundation
import Observation

extension AppContainer {
    /// Bookable tour packages shown on the tour landing page.
    var tourPackageList: AsyncResource<[TourPackage]> {
        provide {
            // ref.watch(authNotifierProvider.select((state) => state.user?.id))
            let userId = TourAuthSelection { [unowned self] in self.authNotifier.state.user?.id }
            return AsyncResource<[TourPackage]>(dependencies: { AnyHashable(userId.value) }) { [unowned self] in
                let result = await self.getTourPackagesUseCase(NoParams())
                switch result {
                case .failure(let failure):
                    throw Exception(failure.message)
                case .success(let packages):
                    return packages
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
private final class TourAuthSelection<Value: Equatable> {
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
