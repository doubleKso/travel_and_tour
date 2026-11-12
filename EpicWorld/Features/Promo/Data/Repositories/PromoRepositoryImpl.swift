// Port of lib/features/promo/data/repositories/promo_repository_impl.dart

import Foundation

final class PromoRepositoryImpl: PromoRepository {
    private let mock: PromoMockService

    init(_ mock: PromoMockService) {
        self.mock = mock
    }

    func getPromos() async -> AppResult<[PromoModel]> {
        // Dart note (api): GET Endpoints.promos via PromoRemoteService.
        //
        // Dart wraps this in `try … catch (e) => UnexpectedFailure(e.toString())`.
        // The in-memory mock cannot throw, so Swift has no error to catch here
        // (a `catch` would be unreachable and rejected as dead code).
        .success(mock.getPromos())
    }
}
