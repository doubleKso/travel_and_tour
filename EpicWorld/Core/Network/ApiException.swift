import Foundation

/// Anything that goes wrong below the repository layer — the port of
/// `app_network`'s `ApiException` (packages/app_network/lib/src/api_exception.dart).
///
/// Repositories catch this and translate it into an `AppResult`; it never
/// reaches a notifier or a view.
///
/// | Dart                                          | Swift                                   |
/// |-----------------------------------------------|-----------------------------------------|
/// | `ApiException.fromDio(e)`                     | `ApiException.fromHTTP(e)`              |
/// | `ApiException.isConnectionIssue(dioEx)`       | `ApiException.isConnectionIssue(httpEx)`|
/// | `ApiException.fromFirebaseFunctions(e)`       | `ApiException.fromFunctions(e)`         |
/// | `ApiException.isFirebaseConnectionIssue(e)`   | `ApiException.isFunctionsConnectionIssue(e)` |
/// | `ApiException.isSessionExpired(e)`            | same                                    |
/// | `ApiException.messageFrom(e, fallback:)`      | same                                    |
/// | `ApiException.firebaseFunctionsMessage(…)`    | same                                    |
/// | `ApiException.callablePayload(data, endpoint:)` | `try ApiException.callablePayload(…)` |
/// | `ApiException.cleanMessage(…)`                | same                                    |
struct ApiException: Error, CustomStringConvertible, Equatable {
    static let defaultFallback = "Something went wrong. Please try again."

    let message: String
    let statusCode: Int?

    init(_ message: String, statusCode: Int? = nil) {
        self.message = message
        self.statusCode = statusCode
    }

    var description: String { message }

    /// True when the failure is "the device could not reach the server",
    /// which repositories map to `.network()`.
    static func isConnectionIssue(_ error: HTTPException) -> Bool {
        switch error.type {
        case .connectionTimeout, .receiveTimeout, .sendTimeout, .connectionError: return true
        default: return false
        }
    }

    static func fromHTTP(_ error: HTTPException) -> ApiException {
        let serverMessage = responseMessage(error.responseData)
        return ApiException(serverMessage ?? cleanMessage(error.message), statusCode: error.statusCode)
    }

    /// Extracts only the human-readable backend message from a callable
    /// error. Details are preferred because the top-level Firebase message is
    /// often a generic label such as "Sign up failed".
    static func fromFunctions(_ error: FunctionsException, fallback: String = defaultFallback) -> ApiException {
        ApiException(firebaseFunctionsMessage(details: error.details, message: error.message, fallback: fallback))
    }

    static func isFunctionsConnectionIssue(_ error: FunctionsException) -> Bool {
        error.code == "unavailable" || error.code == "deadline-exceeded"
    }

    /// True when the backend rejected the call because the session's access
    /// token is no longer good — the one failure the app can fix by itself,
    /// by renewing the session (`authRefresh` + `authMe`) and calling again.
    ///
    /// Matches on the backend's wording ("Access token expired") because the
    /// callable protocol carries no status code the client can branch on.
    static func isSessionExpired(_ error: Any?) -> Bool {
        guard let error = Dart.unwrap(error) else { return false }
        let text: String
        if let functions = error as? FunctionsException {
            text = "\(functions.code) \(functions.message ?? "null") \(Dart.interpolate(functions.details))".lowercased()
        } else {
            text = String(describing: error).lowercased()
        }
        if text.contains("unauthenticated") { return true }
        if !text.contains("token") && !text.contains("session") { return false }
        return text.contains("expired") || text.contains("invalid") || text.contains("unauthorized")
    }

    /// Converts any caught error into display-safe text without exception
    /// class names or Firebase code prefixes.
    static func messageFrom(_ error: Error, fallback: String = defaultFallback) -> String {
        if let functions = error as? FunctionsException {
            return fromFunctions(functions, fallback: fallback).message
        }
        return cleanMessage(dartToString(error), fallback: fallback)
    }

    /// Details-first callable error extraction, public for contract tests.
    static func firebaseFunctionsMessage(
        details: Any? = nil,
        message: String? = nil,
        fallback: String = defaultFallback
    ) -> String {
        if let responseMessage = responseMessage(details) { return responseMessage }
        return cleanMessage(message, fallback: fallback)
    }

    /// Unwraps a callable response and turns a returned failure envelope into
    /// an `ApiException` carrying only the backend's message.
    static func callablePayload(_ data: Any?, endpoint: String) throws -> JSON {
        guard let body = Dart.map(data) else {
            throw FormatException("Unexpected result returned by \(endpoint).")
        }
        let payload = Dart.map(body["result"]) ?? body
        let failed = Dart.bool(body["success"]) == false
            || Dart.bool(body["ok"]) == false
            || Dart.bool(payload["success"]) == false
            || Dart.bool(payload["ok"]) == false
            || !Dart.isNull(body["error"])
            || !Dart.isNull(payload["error"])
        if failed {
            let details = firstNonNull(payload["error"], body["error"], payload["details"], body["details"]) ?? payload
            let message = Dart.str(firstNonNull(payload["message"], body["message"]))
            throw ApiException(firebaseFunctionsMessage(details: details, message: message))
        }
        return payload
    }

    static func cleanMessage(_ value: String?, fallback: String = defaultFallback) -> String {
        var message = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if message.isEmpty { return fallback }

        if let range = message.range(of: #"^\[firebase_functions/[^\]]+\]\s*"#, options: [.regularExpression, .caseInsensitive]) {
            message.removeSubrange(range)
        }
        for prefix in ["FirebaseFunctionsException: ", "FormatException: ", "StateError: ", "Exception: "] {
            if message.hasPrefix(prefix) {
                message = String(message.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        return message.isEmpty ? fallback : message
    }

    // MARK: - Private

    private static func firstNonNull(_ values: Any?...) -> Any? {
        for value in values where !Dart.isNull(value) { return Dart.unwrap(value) }
        return nil
    }

    /// Dart `error.toString()` for the error types this app throws.
    private static func dartToString(_ error: Error) -> String {
        if let describable = error as? CustomStringConvertible { return describable.description }
        let nsError = error as NSError
        return nsError.localizedDescription
    }

    private static func responseMessage(_ value: Any?) -> String? {
        guard let value = Dart.unwrap(value) else { return nil }
        if let text = value as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return nil }
            if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
                // The backend sent ordinary text that merely resembles JSON
                // when decoding fails.
                if let decoded = try? jsonDecode(trimmed) { return responseMessage(decoded) }
            }
            return cleanMessage(trimmed)
        }
        if let map = Dart.map(value) {
            for key in ["message", "Message", "errorMessage", "error_message", "description", "Description"] {
                if let direct = Dart.unwrap(map[key]) as? String,
                   !direct.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return cleanMessage(direct)
                }
            }
            for key in ["error", "errors", "data", "result", "details", "response"] {
                if let nested = responseMessage(map[key]) { return nested }
            }
            return nil
        }
        if let list = Dart.list(value) {
            for item in list {
                if let nested = responseMessage(item) { return nested }
            }
            return nil
        }
        return nil
    }
}

/// Converts anything a data source throws into a display-safe `AppFailure` —
/// the port of `app_network`'s `FailureMapper`.
///
/// ```swift
/// do {
///     return .success(try await remote.getActiveHotels())
/// } catch {
///     return .failure(FailureMapper.from(error))
/// }
/// ```
enum FailureMapper {
    static func from(_ error: Error) -> AppFailure {
        if let failure = error as? AppFailure { return failure }
        if let functions = error as? FunctionsException {
            if ApiException.isFunctionsConnectionIssue(functions) { return .network() }
            return .server(message: ApiException.fromFunctions(functions).message)
        }
        if let http = error as? HTTPException {
            if ApiException.isConnectionIssue(http) { return .network() }
            let exception = ApiException.fromHTTP(http)
            return .server(message: exception.message, statusCode: exception.statusCode)
        }
        if let api = error as? ApiException {
            return .server(message: ApiException.messageFrom(api), statusCode: api.statusCode)
        }
        if error is FormatException {
            return .parsing(ApiException.messageFrom(error))
        }
        return .unexpected(ApiException.messageFrom(error))
    }
}
