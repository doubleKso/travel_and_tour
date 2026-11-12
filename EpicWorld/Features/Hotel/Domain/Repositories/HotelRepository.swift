// Port of lib/features/hotel/domain/repositories/hotel_repository.dart
import Foundation

/// Read side of the hotel catalogue.
protocol HotelRepository: AnyObject {
    func getHotels() async -> AppResult<[HotelModel]>

    func getCategories() async -> AppResult<[HotelCategory]>
}
