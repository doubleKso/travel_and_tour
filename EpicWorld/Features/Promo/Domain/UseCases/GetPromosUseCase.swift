// Port of lib/features/promo/domain/usecases/get_promos_use_case.dart

import Foundation

/// Promotions for the home carousel.
final class GetPromosUseCase: UseCase {
    private let repository: PromoRepository

    init(_ repository: PromoRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: NoParams) async -> AppResult<[PromoModel]> {
        await repository.getPromos()
    }
}
