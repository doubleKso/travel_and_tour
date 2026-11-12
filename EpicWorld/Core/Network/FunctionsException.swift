import Foundation
import FirebaseFunctions

/// The Swift side of FlutterFire's `FirebaseFunctionsException`: a callable
/// failed with a Functions error `code`, a top-level `message`, and the
/// backend's `details` payload.
///
/// `code` uses the same strings as Dart (`unavailable`, `deadline-exceeded`,
/// `unauthenticated`, `internal` …) so ported checks compare the same values.
struct FunctionsException: Error, CustomStringConvertible {
    let code: String
    let message: String?
    let details: Any?

    init(code: String, message: String? = nil, details: Any? = nil) {
        self.code = code
        self.message = message
        self.details = details
    }

    /// Converts whatever `HTTPSCallable.call` threw.
    init(_ error: Error) {
        let nsError = error as NSError
        if nsError.domain == FunctionsErrorDomain {
            self.init(
                code: Self.codeName(nsError.code),
                message: nsError.localizedDescription,
                details: nsError.userInfo[FunctionsErrorDetailsKey]
            )
        } else if nsError.domain == NSURLErrorDomain {
            // The plugin reports transport failures as `unavailable` /
            // `deadline-exceeded`, which repositories map to NetworkFailure.
            let timedOut = nsError.code == NSURLErrorTimedOut
            self.init(
                code: timedOut ? "deadline-exceeded" : "unavailable",
                message: nsError.localizedDescription
            )
        } else {
            self.init(code: "unknown", message: nsError.localizedDescription)
        }
    }

    /// Matches `FirebaseFunctionsException.toString()`.
    var description: String { "[firebase_functions/\(code)] \(message ?? "")" }

    /// `FunctionsErrorCode` raw values → FlutterFire's code strings.
    static func codeName(_ rawValue: Int) -> String {
        switch rawValue {
        case 0: return "ok"
        case 1: return "cancelled"
        case 2: return "unknown"
        case 3: return "invalid-argument"
        case 4: return "deadline-exceeded"
        case 5: return "not-found"
        case 6: return "already-exists"
        case 7: return "permission-denied"
        case 8: return "resource-exhausted"
        case 9: return "failed-precondition"
        case 10: return "aborted"
        case 11: return "out-of-range"
        case 12: return "unimplemented"
        case 13: return "internal"
        case 14: return "unavailable"
        case 15: return "data-loss"
        case 16: return "unauthenticated"
        default: return "unknown"
        }
    }
}

/// Invokes a Firebase callable by URL — the port of
/// `FirebaseFunctions.instance.httpsCallableFromUrl(url).call(data)`.
///
/// Remote services take a `CallableClient` the way Dart services take a
/// `FirebaseFunctions`, and tests hand them a fake `CallableInvoking`.
///
/// ```swift
/// // Dart:
/// // final response = await _functions
/// //     .httpsCallableFromUrl(F.functionsUrl(Endpoints.searchFlights))
/// //     .call(body);
/// // final payload = ApiException.callablePayload(response.data, endpoint: Endpoints.searchFlights);
/// let data = try await functions.call(F.functionsUrl(Endpoints.searchFlights), body)
/// let payload = try ApiException.callablePayload(data, endpoint: Endpoints.searchFlights)
/// ```
protocol CallableInvoking {
    /// Returns the callable's decoded `data`; throws `FunctionsException`.
    func call(_ url: String, _ data: Any?, timeout: TimeInterval?) async throws -> Any?
}

extension CallableInvoking {
    func call(_ url: String, _ data: Any? = nil) async throws -> Any? {
        try await call(url, data, timeout: nil)
    }
}

final class CallableClient: CallableInvoking {
    private let functions: () -> Functions

    /// `functions` is resolved lazily so Firebase is configured first.
    init(functions: @escaping () -> Functions = { Functions.functions() }) {
        self.functions = functions
    }

    func call(_ url: String, _ data: Any?, timeout: TimeInterval?) async throws -> Any? {
        guard let endpoint = URL(string: url) else {
            throw FunctionsException(code: "invalid-argument", message: "Invalid callable URL: \(url)")
        }
        let callable = functions().httpsCallable(endpoint)
        if let timeout { callable.timeoutInterval = timeout }
        superPrint(url, title: "callable →", isApi: true)
        do {
            let result = try await callable.call(data)
            return result.data
        } catch {
            let wrapped = FunctionsException(error)
            superPrint("\(wrapped)", title: "callable ✗ \(url)", isApi: true)
            throw wrapped
        }
    }
}
