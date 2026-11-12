import Foundation

/// Why an operation did not produce data — the Swift side of `app_core`'s
/// sealed `Failure` hierarchy (packages/app_core/lib/src/errors/failures.dart).
///
/// What a repository returns instead of throwing, so presentation code can
/// branch on the kind of failure and show `message` without ever seeing an
/// error. Failures are values: equal cases with equal fields compare equal.
///
/// | Dart                                   | Swift                              |
/// |----------------------------------------|------------------------------------|
/// | `NetworkFailure()`                     | `.network()`                       |
/// | `ServerFailure(message: m, statusCode: c)` | `.server(message: m, statusCode: c)` |
/// | `CacheFailure(m)`                      | `.cache(m)`                        |
/// | `ParsingFailure(m)`                    | `.parsing(m)`                      |
/// | `UnexpectedFailure(m)`                 | `.unexpected(m)`                   |
/// | `failure is NetworkFailure`            | `failure.isNetwork`                |
/// | `failure.message`                      | `failure.message`                  |
enum AppFailure: Error, Equatable, CustomStringConvertible {
    /// The device could not reach the server (offline, timeout, DNS…).
    case network(String = "No internet connection.")
    /// The server answered, but refused or failed the request. `statusCode`
    /// is the HTTP status when the transport has one (callables do not).
    case server(message: String, statusCode: Int? = nil)
    /// Local persistence failed (preferences, keychain, a device cache).
    case cache(String)
    /// A payload could not be parsed into the expected shape.
    case parsing(String)
    /// Anything not covered above.
    case unexpected(String)

    /// Display-safe text, ready for a snack bar or an inline error.
    var message: String {
        switch self {
        case .network(let message): return message
        case .server(let message, _): return message
        case .cache(let message), .parsing(let message), .unexpected(let message):
            return message
        }
    }

    var isNetwork: Bool { if case .network = self { return true } else { return false } }
    var isServer: Bool { if case .server = self { return true } else { return false } }
    var isCache: Bool { if case .cache = self { return true } else { return false } }
    var isParsing: Bool { if case .parsing = self { return true } else { return false } }
    var isUnexpected: Bool { if case .unexpected = self { return true } else { return false } }

    /// HTTP status of a `.server` failure, when the transport had one.
    var statusCode: Int? {
        if case .server(_, let code) = self { return code }
        return nil
    }

    /// Matches Dart's `'$runtimeType($message)'`.
    var description: String {
        switch self {
        case .network: return "NetworkFailure(\(message))"
        case .server: return "ServerFailure(\(message))"
        case .cache: return "CacheFailure(\(message))"
        case .parsing: return "ParsingFailure(\(message))"
        case .unexpected: return "UnexpectedFailure(\(message))"
        }
    }
}

/// Dart's `FormatException`: thrown by parsers when a payload has the wrong
/// shape. `FailureMapper` turns it into `.parsing`.
struct FormatException: Error, CustomStringConvertible, Equatable {
    let message: String
    init(_ message: String = "") { self.message = message }
    var description: String { message.isEmpty ? "FormatException" : "FormatException: \(message)" }
}

/// Dart's `StateError`: an operation was attempted in a state that forbids it.
struct StateError: Error, CustomStringConvertible, Equatable {
    let message: String
    init(_ message: String) { self.message = message }
    var description: String { "StateError: \(message)" }
}

/// Dart's plain `Exception('message')`; prints as `Exception: message`, which
/// `ApiException.cleanMessage` strips back to the message.
struct Exception: Error, CustomStringConvertible, Equatable {
    let message: String
    init(_ message: String) { self.message = message }
    var description: String { "Exception: \(message)" }
}

/// Dart's `UnimplementedError`, used by fakes and not-yet-supported paths.
struct UnimplementedError: Error, CustomStringConvertible {
    let message: String
    init(_ message: String = "") { self.message = message }
    var description: String { message.isEmpty ? "UnimplementedError" : "UnimplementedError: \(message)" }
}
