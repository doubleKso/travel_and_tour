import Foundation

/// Envelope every Epic World REST response is unwrapped into — the port of
/// `app_network`'s `AppResponse<T>`.
///
/// ```swift
/// let response = try await http.get(Endpoints.hotels)
/// return AppResponse.fromRawJson(Dart.map(response.data) ?? [:]) { json in
///     Dart.maps(json).map(HotelDto.fromJson)
/// }
/// ```
struct AppResponse<T> {
    /// Whether the server reported the call as successful.
    let success: Bool
    /// Server-side status/business code, when the API sends one.
    let code: String?
    /// Human-readable message — safe to surface in a snack bar.
    let message: String
    /// Longer description, when the API sends one.
    let description: String?
    /// The parsed payload. Nil on failure.
    let data: T?
    /// HTTP status code (added client-side, not from the body).
    let statusCode: Int
    /// HTTP status message (added client-side, not from the body).
    let statusMessage: String

    init(
        success: Bool = false,
        code: String? = nil,
        message: String,
        description: String? = nil,
        data: T? = nil,
        statusCode: Int = 200,
        statusMessage: String = "OK"
    ) {
        self.success = success
        self.code = code
        self.message = message
        self.description = description
        self.data = data
        self.statusCode = statusCode
        self.statusMessage = statusMessage
    }

    /// Failure envelope built client-side (no usable body).
    static func failure(_ message: String, statusCode: Int = 0) -> AppResponse<T> {
        AppResponse(success: false, message: message, statusCode: statusCode, statusMessage: message)
    }

    /// Parses the standard body `{ status, statusCode, message, description, resultObject }`.
    static func fromRawJson(_ json: JSON, _ fromJsonT: (Any?) -> T) -> AppResponse<T> {
        AppResponse(
            success: Dart.int(json["status"]) == 200 || Dart.bool(json["success"]) == true,
            code: Dart.str(Dart.unwrap(json["code"]) ?? Dart.unwrap(json["statusCode"])),
            message: Dart.str(Dart.unwrap(json["message"]) ?? Dart.unwrap(json["Message"])) ?? "",
            description: Dart.str(Dart.unwrap(json["description"]) ?? Dart.unwrap(json["Description"])) ?? "",
            data: fromJsonT(Dart.unwrap(json["resultObject"]) ?? Dart.unwrap(json["data"])),
            statusCode: Dart.isInt(json["statusCode"]) ? (Dart.int(json["statusCode"]) ?? 200) : 200,
            statusMessage: Dart.str(json["statusMessage"]) ?? "OK"
        )
    }
}
