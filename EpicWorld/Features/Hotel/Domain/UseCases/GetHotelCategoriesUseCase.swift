// Port of lib/features/hotel/domain/usecases/get_hotel_categories_use_case.dart
import Foundation

/// Stay categories (business, family, luxury, …).
final class GetHotelCategoriesUseCase: UseCase {
    private let repository: HotelRepository

    init(_ repository: HotelRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: NoParams) async -> AppResult<[HotelCategory]> {
        await repository.getCategories()
    }
}
