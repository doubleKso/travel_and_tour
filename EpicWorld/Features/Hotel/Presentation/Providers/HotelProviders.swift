// Port of lib/features/hotel/presentation/providers/hotel_providers.dart
import Foundation
import Observation

/// `ref.watch(authNotifierProvider.select((state) => state.user?.id))`.
///
/// `AsyncResource` reloads whenever anything its `dependencies` closure read
/// changes, so depending on `authNotifier.state` directly would reload the
/// catalogue on each auth update (loading flags, error text, a profile
/// refresh). This keeps an observable copy of the selected value that only
/// changes when the value itself does — Riverpod's `select` — and the hotel
/// list depends on it instead.
@MainActor
@Observable
private final class HotelUserIdSelection {
    private(set) var value: String?
    @ObservationIgnored private let select: () -> String?

    init(_ select: @escaping () -> String?) {
        self.select = select
        self.value = select()
        track()
    }

    private func track() {
        let current = withObservationTracking {
            select()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.track() }
        }
        if current != value { value = current }
    }
}

extension AppContainer {
    /// The user-id selection `hotelList` watches. Created before the resource
    /// so its own first read of the auth state is not recorded as one of the
    /// resource's dependencies.
    private var hotelUserIdSelection: HotelUserIdSelection {
        provide { HotelUserIdSelection { [unowned self] in self.authNotifier.state.user?.id } }
    }

    /// `hotelListProvider` — featured hotels for the home row and the hotel
    /// landing page.
    var hotelList: AsyncResource<[HotelModel]> {
        provide {
            let selection = hotelUserIdSelection
            return AsyncResource(dependencies: { AnyHashable(selection.value) }) { [unowned self] in
                let result = await self.getHotelsUseCase(NoParams())
                return try result.fold(
                    { (failure: AppFailure) -> [HotelModel] in throw Exception(failure.message) },
                    // The Hotels tab and Home's Popular Hotels carousel share this catalogue,
                    // so prioritising here keeps five-star properties first everywhere.
                    { hotels in fiveStarHotelsFirst(hotels) }
                )
            }
        }
    }

    /// `hotelCategoryListProvider` — stay categories (business, family,
    /// luxury, …).
    var hotelCategoryList: AsyncResource<[HotelCategory]> {
        provide {
            AsyncResource { [unowned self] in
                let result = await self.getHotelCategoriesUseCase(NoParams())
                return try result.fold(
                    { (failure: AppFailure) -> [HotelCategory] in throw Exception(failure.message) },
                    { categories in categories }
                )
            }
        }
    }
}
