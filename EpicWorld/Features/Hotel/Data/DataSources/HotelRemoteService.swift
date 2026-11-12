// Port of lib/features/hotel/data/datasources/hotel_remote_service.dart
import Foundation

/// Reads the public active-hotel catalogue from `dcExec`.
final class HotelRemoteService {
    private let functions: CallableInvoking

    init(_ functions: CallableInvoking) {
        self.functions = functions
    }

    func getActiveHotels(accessToken: String? = nil) async throws -> [HotelModel] {
        let body: JSON = [
            "operation": "ListActiveHotels",
            "variables": JSON(),
            // Dart sends an explicit `null` for a guest.
            "accessToken": accessToken.map { $0 as Any } ?? NSNull(),
        ]
        let data = try await functions.call(F.functionsUrl(Endpoints.dcExec), body)
        let payload = try ApiException.callablePayload(
            data,
            endpoint: "\(Endpoints.dcExec)/ListActiveHotels"
        )
        return Dart.maps(payload["hotels"]).map(HotelModel.fromActiveApiJson)
    }
}
