// Port of lib/features/booking/data/datasources/smartpay_callable_service.dart

import Foundation

/// Firebase callable boundary for the Epic World backend's SmartPay flow.
///
/// Merchant credentials (`SMARTPAY_API_KEY`, `SMARTPAY_API_SECRET`,
/// `SMARTPAY_WEBHOOK_SECRET`) stay on the backend, along with the SmartPay
/// bearer-token cache and the `smartpayCallback` webhook SmartPay posts to.
/// The client sends only the booking identity and the customer's Epic World
/// session token, and learns the outcome by asking `getPaymentStatus`.
///
/// There is deliberately no `smartpayCallback` method here: that endpoint is
/// SmartPay talking to the backend, and a client that could call it could
/// forge a paid booking.
final class SmartPayCallableService {
    private let functions: CallableInvoking

    init(_ functions: CallableInvoking) {
        self.functions = functions
    }

    func createPaymentIntent(_ request: CreatePaymentIntentRequest) async throws -> CreatePaymentIntentResponse {
        let endpoint = Endpoints.createPaymentIntent
        let url = F.functionsUrl(endpoint)
        let body = request.toJson()
        Self.logRequest(endpoint: endpoint, url: url, body: body)
        do {
            let response = try await functions.call(url, body)
            Self.logResponse(endpoint: endpoint, response: response)
            let payload = try ApiException.callablePayload(response, endpoint: endpoint)
            return CreatePaymentIntentResponse.fromJson(payload)
        } catch let error as FunctionsException {
            Self.logError(endpoint, error)
            throw error
        } catch {
            Self.logError(endpoint, error)
            throw error
        }
    }

    func getPaymentStatus(_ request: GetPaymentStatusRequest) async throws -> GetPaymentStatusResponse {
        let endpoint = Endpoints.getPaymentStatus
        let url = F.functionsUrl(endpoint)
        let body = request.toJson()
        Self.logRequest(endpoint: endpoint, url: url, body: body)
        do {
            let response = try await functions.call(url, body)
            Self.logResponse(endpoint: endpoint, response: response)
            let payload = try ApiException.callablePayload(response, endpoint: endpoint)
            return GetPaymentStatusResponse.fromJson(payload)
        } catch let error as FunctionsException {
            Self.logError(endpoint, error)
            throw error
        } catch {
            Self.logError(endpoint, error)
            throw error
        }
    }

    /// SmartPay calls happen from the Pay Now flow and its later status checks.
    /// Keeping their diagnostics at the callable boundary covers both places,
    /// including the status check after an app/browser return.
    private static func logRequest(endpoint: String, url: String, body: JSON) {
        #if DEBUG
        superPrint(
            pretty(["url": url, "data": redact(body) ?? NSNull()] as JSON),
            title: "SmartPay \(endpoint) request",
            isApi: true
        )
        #endif
    }

    private static func logResponse(endpoint: String, response: Any?) {
        #if DEBUG
        superPrint(
            pretty(redact(response)),
            title: "SmartPay \(endpoint) response",
            isApi: true
        )
        #endif
    }

    private static func logError(_ endpoint: String, _ error: Error) {
        #if DEBUG
        let details: JSON
        if let error = error as? FunctionsException {
            details = [
                "type": "FirebaseFunctionsException",
                "code": error.code,
                "message": (error.message as Any?) ?? NSNull(),
                "details": redact(error.details) ?? NSNull(),
            ]
        } else {
            details = ["type": String(describing: type(of: error)), "message": String(describing: error)]
        }
        superPrint(
            pretty(details),
            title: "SmartPay \(endpoint) error",
            isApi: true
        )
        #endif
    }

    /// Dart `JsonEncoder.withIndent('  ').convert(value)`, falling back to
    /// `value.toString()`.
    private static func pretty(_ value: Any?) -> String {
        let object: Any = Dart.unwrap(value) ?? NSNull()
        guard let data = try? JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]
        ), let text = String(data: data, encoding: .utf8) else {
            return Dart.interpolate(value)
        }
        return text
    }

    /// Payment URLs and session credentials are one-click/payment secrets; the
    /// rest of the API shape remains visible in debug logs for troubleshooting.
    private static func redact(_ value: Any?) -> Any? {
        if let map = Dart.map(value) {
            var out = JSON()
            for (key, element) in map {
                out[key] = isSensitive(key) ? mask(Dart.str(element)) : (redact(element) ?? NSNull())
            }
            return out
        }
        if let list = Dart.list(value) {
            return list.map { redact($0) ?? NSNull() }
        }
        return Dart.unwrap(value)
    }

    private static func isSensitive(_ key: String) -> Bool {
        switch key.lowercased() {
        case "accesstoken", "token", "authorization", "secret", "apikey",
             "paymenturl", "email", "contactemail", "phone", "contactphone":
            return true
        default:
            return false
        }
    }

    private static func mask(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "<empty>" }
        if value.count <= 4 { return "****" }
        return "\(value.prefix(2))…\(value.suffix(2))"
    }
}
