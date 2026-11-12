// Port of lib/features/promo/di/promo_module.dart

import Foundation

extension AppContainer {
    /// `promoMockServiceProvider`.
    var promoMockService: PromoMockService {
        provide { PromoMockService() }
    }

    /// `promoRepositoryProvider`.
    var promoRepository: PromoRepository {
        provide { PromoRepositoryImpl(promoMockService) as PromoRepository }
    }

    // ---- Use cases ------------------------------------------------------------

    /// `getPromosUseCaseProvider`.
    var getPromosUseCase: GetPromosUseCase {
        provide { GetPromosUseCase(promoRepository) }
    }
}
