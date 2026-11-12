// Port of lib/features/auth/domain/entities/auth_user.dart
import Foundation

/// The signed-in account, as the rest of the app sees it.
///
/// Domain models hold no JSON and no UI types — `AuthUserDto` (below the
/// repository) owns parsing and maps into this with `toDomain()`.
struct AuthUser: Hashable {
    let id: String
    let username: String
    let email: String
    let displayName: String

    /// Mobile number returned by the account API, when the account has one.
    let phone: String
    let avatarUrl: String
    let role: String

    /// Loyalty points driving the membership tier on the Member tab.
    let points: Int

    /// Bearer token for authenticated calls; empty for a guest.
    let token: String

    init(
        id: String,
        username: String,
        email: String,
        displayName: String,
        phone: String = "",
        avatarUrl: String = "",
        role: String = "user",
        points: Int = 0,
        token: String = ""
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.displayName = displayName
        self.phone = phone
        self.avatarUrl = avatarUrl
        self.role = role
        self.points = points
        self.token = token
    }

    /// The demo account that unlocks the redesigned "Version 2" home.
    static let version2Email = "v2@test.com"

    var isVersion2: Bool { email.lowercased() == AuthUser.version2Email }

    func copyWith(
        id: String? = nil,
        username: String? = nil,
        email: String? = nil,
        displayName: String? = nil,
        phone: String? = nil,
        avatarUrl: String? = nil,
        role: String? = nil,
        points: Int? = nil,
        token: String? = nil
    ) -> AuthUser {
        AuthUser(
            id: id ?? self.id,
            username: username ?? self.username,
            email: email ?? self.email,
            displayName: displayName ?? self.displayName,
            phone: phone ?? self.phone,
            avatarUrl: avatarUrl ?? self.avatarUrl,
            role: role ?? self.role,
            points: points ?? self.points,
            token: token ?? self.token
        )
    }
}
