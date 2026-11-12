// Port of lib/features/tour/domain/repositories/tour_repository.dart

import Foundation

/// Read side of the tour catalogue.
protocol TourRepository: AnyObject {
    func getPackages() async -> AppResult<[TourPackage]>
}
