// Port of lib/features/hotel/domain/usecases/get_hotels_use_case.dart
import Foundation

/// The public hotel catalogue.
final class GetHotelsUseCase: UseCase {
    private let repository: HotelRepository

    init(_ repository: HotelRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: NoParams) async -> AppResult<[HotelModel]> {
        await repository.getHotels()
    }
}
