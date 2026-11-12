// Port of lib/features/auth/data/models/auth_register_response.dart
import Foundation

/// A permission exception returned for a newly registered account.
struct AuthPermissionOverride {
    let permission: String
    let effect: String

    init(permission: String, effect: String) {
        self.permission = permission
        self.effect = effect
    }

    static func fromJson(_ json: JSON) -> AuthPermissionOverride {
        AuthPermissionOverride(
            permission: Dart.str(json["permission"]) ?? "",
            effect: Dart.str(json["effect"]) ?? ""
        )
    }
}

/// Response payload from `POST /auth/register`.
struct AuthRegisterResponse {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let roles: [String]
    let customRoleCodes: [String]
    let permissionOverrides: [AuthPermissionOverride]
    let permissions: [String]
    let status: String
    let note: String
    let decisionReason: String
    let avatarUrl: String
    let createdAt: String
    let lastLoginAt: String

    init(
        id: String,
        firstName: String,
        lastName: String,
        email: String,
        roles: [String],
        customRoleCodes: [String],
        permissionOverrides: [AuthPermissionOverride],
        permissions: [String],
        status: String,
        note: String,
        decisionReason: String,
        avatarUrl: String,
        createdAt: String,
        lastLoginAt: String
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.roles = roles
        self.customRoleCodes = customRoleCodes
        self.permissionOverrides = permissionOverrides
        self.permissions = permissions
        self.status = status
        self.note = note
        self.decisionReason = decisionReason
        self.avatarUrl = avatarUrl
        self.createdAt = createdAt
        self.lastLoginAt = lastLoginAt
    }

    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func fromJson(_ json: JSON) -> AuthRegisterResponse {
        AuthRegisterResponse(
            id: Dart.str(json["id"]) ?? "",
            firstName: Dart.str(json["firstName"]) ?? "",
            lastName: Dart.str(json["lastName"]) ?? "",
            email: Dart.str(json["email"]) ?? "",
            roles: stringList(json["roles"]),
            customRoleCodes: stringList(json["customRoleCodes"]),
            permissionOverrides: permissionOverridesFrom(json["permissionOverrides"]),
            permissions: stringList(json["permissions"]),
            status: Dart.str(json["status"]) ?? "",
            note: Dart.str(json["note"]) ?? "",
            decisionReason: Dart.str(json["decisionReason"]) ?? "",
            avatarUrl: Dart.str(json["avatarUrl"]) ?? "",
            createdAt: Dart.str(json["createdAt"]) ?? "",
            lastLoginAt: Dart.str(json["lastLoginAt"]) ?? ""
        )
    }

    /// The registration endpoint does not return a login token or username.
    /// Keep the caller-provided username until the user signs in separately.
    func toAuthUserDto(username: String, token: String? = nil) -> AuthUserDto {
        AuthUserDto(
            id: id,
            userName: username,
            email: email,
            displayName: !fullName.isEmpty ? fullName : username,
            token: token
        )
    }

    private static func stringList(_ value: Any?) -> [String] {
        (Dart.list(value) ?? []).map { Dart.interpolate($0) }
    }

    private static func permissionOverridesFrom(_ value: Any?) -> [AuthPermissionOverride] {
        Dart.maps(value).map(AuthPermissionOverride.fromJson)
    }
}
