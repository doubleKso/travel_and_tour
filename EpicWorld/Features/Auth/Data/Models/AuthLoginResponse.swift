// Port of lib/features/auth/data/models/auth_login_response.dart
import Foundation

/// Successful payload returned by either REST login or `authSignin`.
struct AuthLoginResponse {
    let accessToken: String
    let refreshToken: String
    let sessionId: String
    let expiresIn: Int
    let user: AuthUserDto

    /// ID the emailed code belongs to when sign-in stopped at the two-step
    /// checkpoint. Empty for a completed sign-in.
    let twoFactorUserId: String

    init(
        accessToken: String,
        refreshToken: String,
        sessionId: String,
        expiresIn: Int,
        user: AuthUserDto,
        twoFactorUserId: String = ""
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.sessionId = sessionId
        self.expiresIn = expiresIn
        self.user = user
        self.twoFactorUserId = twoFactorUserId
    }

    /// `authSignin` withholds the session for an account with two-factor
    /// authentication on, answering with the ID the emailed code belongs to
    /// instead. Deployments word the flag differently (and some send none at
    /// all), so the reliable test is a payload that names a user but issues no
    /// token — there is nothing to sign in with until the code is verified.
    var requiresTwoFactor: Bool {
        accessToken.isEmpty && !twoFactorUserId.isEmpty
    }

    static func fromJson(_ json: JSON) -> AuthLoginResponse {
        AuthLoginResponse(
            accessToken: Dart.str(json["accessToken"]) ?? "",
            refreshToken: Dart.str(json["refreshToken"]) ?? "",
            sessionId: Dart.str(json["sessionId"]) ?? "",
            expiresIn: Dart.int(json["expiresIn"]) ?? 0,
            user: userFromJson(json["user"]),
            twoFactorUserId: twoFactorUserIdFrom(json)
        )
    }

    func toAuthUserDto(username: String? = nil) -> AuthUserDto {
        user.copyWith(token: accessToken, userName: username)
    }

    /// Maps the common user payload shared by `authSignin` and `authMe`.
    static func userFromJson(_ rawUser: Any?) -> AuthUserDto {
        let user = Dart.map(rawUser) ?? [:]
        let firstName = Dart.str(user["firstName"]) ?? ""
        let lastName = Dart.str(user["lastName"]) ?? ""
        let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
        return AuthUserDto(
            id: Dart.interpolate(Dart.unwrap(user["id"]) ?? Dart.unwrap(user["uid"]) ?? ""),
            userName: Dart.interpolate(
                Dart.unwrap(user["userName"]) ?? Dart.unwrap(user["username"]) ?? Dart.unwrap(user["email"]) ?? ""
            ),
            email: Dart.str(user["email"]) ?? "",
            displayName: Dart.str(user["displayName"])
                ?? Dart.str(user["name"])
                ?? (fullName.isEmpty ? nil : fullName),
            phone: phoneFromUser(user),
            avatarUrl: Dart.str(user["avatarUrl"]),
            role: Dart.str(user["role"]),
            points: Dart.int(user["points"])
        )
    }
}

private func phoneFromUser(_ user: JSON) -> String? {
    let value = Dart.unwrap(user["phone"])
        ?? Dart.unwrap(user["phoneNumber"])
        ?? Dart.unwrap(user["phoneNo"])
        ?? Dart.unwrap(user["mobile"])
        ?? Dart.unwrap(user["mobileNumber"])
        ?? Dart.unwrap(user["contactPhone"])
    let phone = Dart.str(value)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return phone.isEmpty ? nil : phone
}

/// The account a two-step challenge was raised for. Read from whichever field
/// the deployment uses, and only trusted when the payload carries no tokens.
private func twoFactorUserIdFrom(_ json: JSON) -> String {
    let user = Dart.map(json["user"])
    let nested: Any? = user.flatMap { Dart.unwrap($0["id"]) ?? Dart.unwrap($0["uid"]) }
    let value = Dart.unwrap(json["userId"])
        ?? Dart.unwrap(json["twoFactorUserId"])
        ?? Dart.unwrap(json["pendingUserId"])
        ?? Dart.unwrap(json["id"])
        ?? nested
    return Dart.str(value)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}
