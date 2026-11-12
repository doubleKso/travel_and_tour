// Port of lib/features/booking/domain/usecases/search_trips_use_case.dart

import Foundation

/// Trips for one leg on one date.
final class SearchTripsUseCase: UseCase {
    private let repository: BookingRepository

    init(_ repository: BookingRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: SearchTripsParams) async -> AppResult<[TripOptionModel]> {
        await repository.searchTrips(
            mode: params.mode,
            date: params.date,
            from: params.from,
            to: params.to
        )
    }
}

/// Dart record `({TravelMode mode, DateTime date, LocationModel from, LocationModel to})`.
typealias SearchTripsParams = (
    mode: TravelMode,
    date: DateTime,
    from: LocationModel,
    to: LocationModel
)
