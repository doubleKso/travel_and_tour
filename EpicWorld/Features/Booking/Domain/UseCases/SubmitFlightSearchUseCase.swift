// Port of lib/features/booking/domain/usecases/submit_flight_search_use_case.dart

import Foundation

/// Runs the user's criteria through live flight search, merged with the
/// enquiry-only schedule catalogue.
final class SubmitFlightSearchUseCase: UseCase {
    private let repository: BookingRepository

    init(_ repository: BookingRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: FlightSearchRequest) async -> AppResult<[TripOptionModel]> {
        await repository.submitFlightSearch(params)
    }
}
