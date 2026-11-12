// Port of lib/features/promo/domain/repositories/promo_repository.dart

import Foundation

/// Read side of the promotions carousel.
protocol PromoRepository: AnyObject {
    func getPromos() async -> AppResult<[PromoModel]>
}
