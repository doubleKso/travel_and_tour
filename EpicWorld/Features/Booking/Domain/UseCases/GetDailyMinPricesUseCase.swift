// Port of lib/features/booking/domain/usecases/get_daily_min_prices_use_case.dart

import Foundation

/// Cheapest fare per day around a date — what the date strip shows under each
/// chip.
final class GetDailyMinPricesUseCase: UseCase {
    private let repository: BookingRepository

    init(_ repository: BookingRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: GetDailyMinPricesParams) async -> AppResult<[DateTime: Double]> {
        await repository.getDailyMinPrices(
            mode: params.mode,
            from: params.from,
            to: params.to,
            around: params.around,
            windowDays: params.windowDays
        )
    }
}

/// Parameters for `GetDailyMinPricesUseCase`. A class rather than a record so
/// `windowDays` keeps its default.
struct GetDailyMinPricesParams {
    let mode: TravelMode
    let from: LocationModel
    let to: LocationModel
    let around: DateTime
    let windowDays: Int

    init(
        mode: TravelMode,
        from: LocationModel,
        to: LocationModel,
        around: DateTime,
        windowDays: Int = 15
    ) {
        self.mode = mode
        self.from = from
        self.to = to
        self.around = around
        self.windowDays = windowDays
    }
}
