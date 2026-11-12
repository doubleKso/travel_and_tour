import Foundation

/// A REST response — Dio's `Response`: status plus the decoded body
/// (JSON object/array when the server says JSON, otherwise text).
struct HTTPResponse {
    let statusCode: Int
    let data: Any?
    let headers: [AnyHashable: Any]
    let url: URL?
}

/// Dio's `DioException`: why a REST call failed.
struct HTTPException: Error, CustomStringConvertible {
    /// Dio's `DioExceptionType`.
    enum Kind: String {
        case connectionTimeout, sendTimeout, receiveTimeout, badCertificate
        case badResponse, cancel, connectionError, unknown
    }

    let type: Kind
    let message: String?
    /// The HTTP status of a `badResponse`.
    let statusCode: Int?
    /// The decoded error body of a `badResponse` (Dio's `response?.data`).
    let responseData: Any?
    let url: URL?

    var description: String { "DioException [\(type.rawValue)]: \(message ?? "")" }
}

/// The one REST client every remote service shares — the port of the app's
/// `DioClient` + `app_network`'s `DioFactory` and `AppInterceptor`.
///
/// Every request carries `Authorization: Bearer <token>` when signed in and
/// `accept-language`, and is logged in debug builds. A non-2xx answer throws
/// `HTTPException(type: .badResponse)` with the decoded body, as Dio does.
/// A rejected request never signs the user out locally.
final class HTTPClient {
    let baseURL: String
    private let session: URLSession
    private let accessToken: () -> String
    private let languageCode: () -> String

    init(
        baseURL: String,
        connectTimeout: TimeInterval = AppConsts.connectTimeout,
        receiveTimeout: TimeInterval = AppConsts.receiveTimeout,
        accessToken: @escaping () -> String,
        languageCode: @escaping () -> String
    ) {
        self.baseURL = baseURL
        self.accessToken = accessToken
        self.languageCode = languageCode
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = max(connectTimeout, receiveTimeout)
        configuration.timeoutIntervalForResource = connectTimeout + receiveTimeout
        session = URLSession(configuration: configuration)
    }

    func get(_ path: String, query: [String: Any]? = nil, headers: [String: String] = [:]) async throws -> HTTPResponse {
        try await request("GET", path, data: nil, query: query, headers: headers)
    }

    func post(_ path: String, data: Any? = nil, query: [String: Any]? = nil, headers: [String: String] = [:]) async throws -> HTTPResponse {
        try await request("POST", path, data: data, query: query, headers: headers)
    }

    func put(_ path: String, data: Any? = nil, query: [String: Any]? = nil, headers: [String: String] = [:]) async throws -> HTTPResponse {
        try await request("PUT", path, data: data, query: query, headers: headers)
    }

    func patch(_ path: String, data: Any? = nil, query: [String: Any]? = nil, headers: [String: String] = [:]) async throws -> HTTPResponse {
        try await request("PATCH", path, data: data, query: query, headers: headers)
    }

    func delete(_ path: String, data: Any? = nil, query: [String: Any]? = nil, headers: [String: String] = [:]) async throws -> HTTPResponse {
        try await request("DELETE", path, data: data, query: query, headers: headers)
    }

    func request(
        _ method: String,
        _ path: String,
        data: Any?,
        query: [String: Any]?,
        headers: [String: String]
    ) async throws -> HTTPResponse {
        guard let url = resolve(path, query: query) else {
            throw HTTPException(type: .unknown, message: "Invalid URL: \(path)", statusCode: nil, responseData: nil, url: nil)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // AppInterceptor.onRequest
        let token = accessToken()
        if !token.isEmpty { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.setValue(languageCode(), forHTTPHeaderField: "accept-language")
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        if let data {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let string = data as? String {
                request.httpBody = Data(string.utf8)
            } else {
                request.httpBody = try? JSONSerialization.data(withJSONObject: data, options: [.fragmentsAllowed])
            }
        }

        superPrint("→ \(method) \(url.absoluteString)", title: "http", isApi: true)
        let received: (Data, URLResponse)
        do {
            received = try await session.data(for: request)
        } catch {
            let failure = Self.exception(for: error, url: url)
            superPrint("✗ \(failure.type.rawValue) \(url.absoluteString)", title: "http", isApi: true)
            throw failure
        }
        let (body, urlResponse) = received

        let http = urlResponse as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        let decoded = Self.decode(body, contentType: http?.value(forHTTPHeaderField: "Content-Type"))
        superPrint("← \(status) \(url.absoluteString)", title: "http", isApi: true)

        guard (200..<300).contains(status) else {
            throw HTTPException(
                type: .badResponse,
                message: "This exception was thrown because the response has a status code of \(status) and RequestOptions.validateStatus was configured to throw for this status code.",
                statusCode: status,
                responseData: decoded,
                url: url
            )
        }
        return HTTPResponse(statusCode: status, data: decoded, headers: http?.allHeaderFields ?? [:], url: url)
    }

    /// Dio's join of `baseUrl` and a relative `path`.
    private func resolve(_ path: String, query: [String: Any]?) -> URL? {
        let joined: String
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            joined = path
        } else {
            let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
            joined = base + (path.hasPrefix("/") ? path : "/" + path)
        }
        guard var components = URLComponents(string: joined) else { return nil }
        if let query, !query.isEmpty {
            var items = components.queryItems ?? []
            for (key, value) in query.sorted(by: { $0.key < $1.key }) {
                if let list = Dart.list(value) {
                    items += list.map { URLQueryItem(name: key, value: Dart.interpolate($0)) }
                } else if !Dart.isNull(value) {
                    items.append(URLQueryItem(name: key, value: Dart.interpolate(value)))
                }
            }
            components.queryItems = items
        }
        return components.url
    }

    private static func decode(_ data: Data, contentType: String?) -> Any? {
        guard !data.isEmpty else { return nil }
        let looksJson = contentType?.lowercased().contains("json") ?? false
        if looksJson || data.first == UInt8(ascii: "{") || data.first == UInt8(ascii: "[") {
            if let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
                return json
            }
        }
        return String(data: data, encoding: .utf8)
    }

    private static func exception(for error: Error, url: URL) -> HTTPException {
        let nsError = error as NSError
        let kind: HTTPException.Kind
        if error is CancellationError {
            kind = .cancel
        } else if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut: kind = .connectionTimeout
            case NSURLErrorCancelled: kind = .cancel
            case NSURLErrorServerCertificateUntrusted, NSURLErrorServerCertificateHasBadDate,
                 NSURLErrorServerCertificateNotYetValid, NSURLErrorServerCertificateHasUnknownRoot,
                 NSURLErrorSecureConnectionFailed:
                kind = .badCertificate
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost,
                 NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost,
                 NSURLErrorDNSLookupFailed, NSURLErrorInternationalRoamingOff,
                 NSURLErrorDataNotAllowed:
                kind = .connectionError
            default: kind = .unknown
            }
        } else {
            kind = .unknown
        }
        return HTTPException(type: kind, message: nsError.localizedDescription, statusCode: nil, responseData: nil, url: url)
    }
}
