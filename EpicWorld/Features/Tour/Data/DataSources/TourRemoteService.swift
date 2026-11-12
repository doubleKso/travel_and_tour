// Port of lib/features/tour/data/datasources/tour_remote_service.dart

import Foundation

/// Loads the public tour catalogue from the shared `dcExec` callable.
final class TourRemoteService {
    private let functions: CallableInvoking

    init(_ functions: CallableInvoking) {
        self.functions = functions
    }

    func getActiveTourPackages(accessToken: String? = nil) async throws -> [TourPackage] {
        let body: JSON = [
            "operation": "ListActiveTourPackages",
            "variables": JSON(),
            // Dart sends an explicit `null` for guests.
            "accessToken": (accessToken as Any?) ?? NSNull(),
        ]
        let result = try await functions.call(F.functionsUrl(Endpoints.dcExec), body)
        let payload = try ApiException.callablePayload(
            result,
            endpoint: "\(Endpoints.dcExec)/ListActiveTourPackages"
        )
        return Dart.maps(payload["tourPackages"]).map(TourPackage.fromActiveApiJson)
    }
}
