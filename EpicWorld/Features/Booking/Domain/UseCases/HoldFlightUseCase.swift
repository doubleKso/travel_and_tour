// Port of lib/features/booking/domain/usecases/hold_flight_use_case.dart

import Foundation

/// Holds the chosen seats and returns the booking reference and PNR.
final class HoldFlightUseCase: UseCase {
    private let repository: BookingRepository

    init(_ repository: BookingRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: FlightHoldRequest) async -> AppResult<FlightHoldResponse> {
        await repository.holdFlight(params)
    }
}
