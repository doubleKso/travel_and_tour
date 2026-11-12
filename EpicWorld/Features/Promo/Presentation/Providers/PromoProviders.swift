// Port of lib/features/promo/presentation/providers/promo_providers.dart

import Foundation

extension AppContainer {
    /// "Special Deals" carousel content (`promoListProvider`).
    var promoList: AsyncResource<[PromoModel]> {
        provide {
            AsyncResource(loader: { [unowned self] in
                let result = await self.getPromosUseCase(NoParams())
                return try result.fold(
                    { (failure: AppFailure) -> [PromoModel] in throw Exception(failure.message) },
                    { promos in promos }
                )
            })
        }
    }
}
