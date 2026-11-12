// Port of lib/features/auth/data/models/auth_refresh_response.dart
import Foundation

/// Session token pair returned by `authRefresh`.
struct AuthRefreshResponse {
    let accessToken: String
    let refreshToken: String
    let sessionId: String
    let expiresIn: Int

    init(accessToken: String, refreshToken: String, sessionId: String, expiresIn: Int) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.sessionId = sessionId
        self.expiresIn = expiresIn
    }

    static func fromJson(_ json: JSON) -> AuthRefreshResponse {
        AuthRefreshResponse(
            accessToken: Dart.str(json["accessToken"]) ?? "",
            refreshToken: Dart.str(json["refreshToken"]) ?? "",
            sessionId: Dart.str(json["sessionId"]) ?? "",
            expiresIn: Dart.int(json["expiresIn"]) ?? 0
        )
    }
}
