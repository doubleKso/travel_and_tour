// Port of lib/features/auth/data/models/auth_user_dto.dart
import Foundation

/// Wire format of an account. Parsing lives here and nowhere else.
///
/// Hand-written `fromJson`/`toJson` today; nothing above the repository
/// changes if they are ever generated.
struct AuthUserDto: Equatable {
    let id: String
    let userName: String
    let email: String
    let displayName: String?
    let phone: String?
    let avatarUrl: String?
    let role: String?
    let points: Int?
    let token: String?

    init(
        id: String,
        userName: String,
        email: String,
        displayName: String? = nil,
        phone: String? = nil,
        avatarUrl: String? = nil,
        role: String? = nil,
        points: Int? = nil,
        token: String? = nil
    ) {
        self.id = id
        self.userName = userName
        self.email = email
        self.displayName = displayName
        self.phone = phone
        self.avatarUrl = avatarUrl
        self.role = role
        self.points = points
        self.token = token
    }

    static func fromJson(_ json: JSON) -> AuthUserDto {
        AuthUserDto(
            id: Dart.interpolate(Dart.unwrap(json["id"]) ?? Dart.unwrap(json["userId"]) ?? ""),
            userName: Dart.interpolate(Dart.unwrap(json["userName"]) ?? Dart.unwrap(json["username"]) ?? ""),
            email: Dart.interpolate(Dart.unwrap(json["email"]) ?? ""),
            displayName: Dart.str(json["displayName"]),
            phone: phoneFrom(json),
            avatarUrl: Dart.str(json["avatarUrl"]),
            role: Dart.str(json["role"]),
            points: Dart.int(json["points"]),
            token: Dart.str(json["token"])
        )
    }

    /// Null fields are written as JSON `null`, exactly as the Dart map does.
    func toJson() -> JSON {
        [
            "id": id,
            "userName": userName,
            "email": email,
            "displayName": orNull(displayName),
            "phone": orNull(phone),
            "avatarUrl": orNull(avatarUrl),
            "role": orNull(role),
            "points": orNull(points),
            "token": orNull(token),
        ]
    }

    func copyWith(token: String? = nil, userName: String? = nil, avatarUrl: String? = nil) -> AuthUserDto {
        AuthUserDto(
            id: id,
            userName: userName ?? self.userName,
            email: email,
            displayName: displayName,
            phone: phone,
            avatarUrl: avatarUrl ?? self.avatarUrl,
            role: role,
            points: points,
            token: token ?? self.token
        )
    }

    func toDomain() -> AuthUser {
        AuthUser(
            id: id,
            username: userName,
            email: email,
            displayName: (displayName?.isEmpty == false) ? displayName! : userName,
            phone: phone ?? "",
            avatarUrl: avatarUrl ?? "",
            role: role ?? "user",
            points: points ?? 0,
            token: token ?? ""
        )
    }
}

/// A Dart `null` map value — JSON `null` (`NSNull`) so the map stays encodable.
private func orNull(_ value: Any?) -> Any {
    value ?? NSNull()
}

private func phoneFrom(_ json: JSON) -> String? {
    let value = Dart.unwrap(json["phone"])
        ?? Dart.unwrap(json["phoneNumber"])
        ?? Dart.unwrap(json["phoneNo"])
        ?? Dart.unwrap(json["mobile"])
        ?? Dart.unwrap(json["mobileNumber"])
        ?? Dart.unwrap(json["contactPhone"])
    let phone = Dart.str(value)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return phone.isEmpty ? nil : phone
}
