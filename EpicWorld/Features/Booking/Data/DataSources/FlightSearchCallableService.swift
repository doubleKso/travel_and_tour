// Port of lib/features/booking/data/datasources/flight_search_callable_service.dart

import Foundation

/// Firebase HTTPS callable access to the live flight search service.
final class FlightSearchCallableService {
    private let functions: CallableInvoking

    init(_ functions: CallableInvoking) {
        self.functions = functions
    }

    func searchFlights(_ request: FlightSearchRequest) async throws -> FlightSearchResponse {
        let data = try await functions.call(F.functionsUrl(Endpoints.searchFlights), request.toJson())
        if Dart.isMap(data) {
            return FlightSearchResponse.fromJson(
                try ApiException.callablePayload(data, endpoint: Endpoints.searchFlights)
            )
        }
        if let text = Dart.unwrap(data) as? String {
            let decoded = try jsonDecode(text)
            if Dart.isMap(decoded) {
                return FlightSearchResponse.fromJson(
                    try ApiException.callablePayload(decoded, endpoint: Endpoints.searchFlights)
                )
            }
        }
        throw FormatException("Unexpected result returned by searchFlights.")
    }
}
