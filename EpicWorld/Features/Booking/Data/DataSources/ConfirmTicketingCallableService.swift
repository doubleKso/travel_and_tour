// Port of lib/features/booking/data/datasources/confirm_ticketing_callable_service.dart

import Foundation

/// Firebase callable client that converts a held booking into issued tickets.
final class ConfirmTicketingCallableService {
    private let functions: CallableInvoking

    init(_ functions: CallableInvoking) {
        self.functions = functions
    }

    func confirmTicketing(_ request: ConfirmTicketingRequest) async throws -> ConfirmTicketingResponse {
        let data = try await functions.call(F.functionsUrl(Endpoints.confirmTicketing), request.toJson())
        let payload = try ApiException.callablePayload(data, endpoint: Endpoints.confirmTicketing)
        return ConfirmTicketingResponse.fromJson(payload)
    }
}
