// Port of lib/features/booking/data/datasources/flight_hold_callable_service.dart

import Foundation

/// Firebase callable client for creating a held flight reservation.
final class FlightHoldCallableService {
    private let functions: CallableInvoking

    init(_ functions: CallableInvoking) {
        self.functions = functions
    }

    func holdFlight(request: FlightHoldRequest, accessToken: String? = nil) async throws -> FlightHoldResponse {
        let url = F.functionsUrl(Endpoints.holdFlight)
        let requestBody = request.toJson(accessToken: accessToken)
        Self.logRequest(url, requestBody)
        do {
            let result = try await functions.call(url, requestBody)
            let body = try ApiException.callablePayload(result, endpoint: Endpoints.holdFlight)
            Self.logResponse(body)
            return FlightHoldResponse.fromJson(body)
        } catch let error as FunctionsException {
            Self.logError(
                "FirebaseFunctionsException "
                    + "code=\(error.code), message=\(error.message ?? "null"), details=\(Dart.interpolate(error.details))"
            )
            throw error
        } catch {
            Self.logError(String(describing: error))
            throw error
        }
    }

    /// Debug-only diagnostics for a failed reservation. Tokens and identifying
    /// document/contact values are masked before they reach the device log.
    private static func logRequest(_ url: String, _ body: JSON) {
        #if DEBUG
        superPrint("holdFlight URL: \(url)")
        superPrint(prettyJson(redactedRequestBody(body)))
        #endif
    }

    private static func logResponse(_ body: JSON) {
        #if DEBUG
        superPrint("holdFlight response: \(jsonEncode(body))")
        #endif
    }

    private static func logError(_ message: String) {
        #if DEBUG
        superPrint("holdFlight failed: \(message)")
        #endif
    }

    /// Dart `JsonEncoder.withIndent('  ').convert(value)`.
    private static func prettyJson(_ value: Any) -> String {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return Dart.describe(value)
        }
        return text
    }

    private static func redactedRequestBody(_ body: JSON) -> JSON {
        var safe = body
        safe["accessToken"] = mask(Dart.str(body["accessToken"]))
        if var contact = Dart.map(body["contact"]) {
            contact["email"] = mask(Dart.str(contact["email"]))
            contact["phone"] = mask(Dart.str(contact["phone"]))
            safe["contact"] = contact
        }
        if let passengers = Dart.list(body["passengers"]) {
            safe["passengers"] = passengers.map { value -> Any in
                guard var passenger = Dart.map(value) else { return value }
                passenger["nrc"] = mask(Dart.str(passenger["nrc"]))
                passenger["passportNo"] = mask(Dart.str(passenger["passportNo"]))
                return passenger
            }
        }
        return safe
    }

    private static func mask(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "<empty>" }
        if value.count <= 4 { return "****" }
        return "\(value.prefix(2))…\(value.suffix(2))"
    }
}
