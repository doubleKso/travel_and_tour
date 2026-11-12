// Port of lib/features/booking/data/datasources/promo_code_callable_service.dart

import Foundation

/// Firebase callable client for validating a promotion during checkout.
final class PromoCodeCallableService {
    private let functions: CallableInvoking

    init(_ functions: CallableInvoking) {
        self.functions = functions
    }

    func checkPromoCode(_ request: PromoCodeCheckRequest) async throws -> PromoCodeCheckResponse {
        let data = try await functions.call(F.functionsUrl(Endpoints.checkPromoCode), request.toJson())
        let payload = try ApiException.callablePayload(data, endpoint: Endpoints.checkPromoCode)
        return PromoCodeCheckResponse.fromJson(payload)
    }
}
