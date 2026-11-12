// Port of lib/features/tour/domain/usecases/get_tour_packages_use_case.dart

import Foundation

/// The public tour package catalogue.
final class GetTourPackagesUseCase: UseCase {
    private let repository: TourRepository

    init(_ repository: TourRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: NoParams) async -> AppResult<[TourPackage]> {
        await repository.getPackages()
    }
}
