// Port of lib/features/member/domain/entities/member_account_models.dart
import Foundation

/// The current member profile returned by `dcExec:GetMe`.
///
/// This intentionally mirrors the account-facing fields returned by the
/// callable. Screens can use the small set they need without falling back to
/// stale data held in the sign-in response.
struct MemberAccount {
    let id: String
    let publicId: String
    let email: String
    let phone: String
    let name: String
    let role: String
    let status: String
    let tier: String
    let points: Int
    let lifetimePoints: Int
    let avatarUrl: String
    let twoFactorEnabled: Bool
    let emailNotifications: Bool
    let smsAlerts: Bool
    let promoOffers: Bool
    let emailVerifiedAt: DateTime?
    let createdAt: DateTime?
    let title: String
    let dob: DateTime?
    let nrc: String
    let nationality: String
    let passport: String
    let addressLine: String
    let township: String
    let city: String
    let region: String

    init(
        id: String,
        publicId: String,
        email: String,
        phone: String,
        name: String,
        role: String,
        status: String,
        tier: String,
        points: Int,
        lifetimePoints: Int,
        avatarUrl: String,
        twoFactorEnabled: Bool,
        emailNotifications: Bool,
        smsAlerts: Bool,
        promoOffers: Bool,
        emailVerifiedAt: DateTime? = nil,
        createdAt: DateTime? = nil,
        title: String,
        dob: DateTime? = nil,
        nrc: String,
        nationality: String,
        passport: String,
        addressLine: String,
        township: String,
        city: String,
        region: String
    ) {
        self.id = id
        self.publicId = publicId
        self.email = email
        self.phone = phone
        self.name = name
        self.role = role
        self.status = status
        self.tier = tier
        self.points = points
        self.lifetimePoints = lifetimePoints
        self.avatarUrl = avatarUrl
        self.twoFactorEnabled = twoFactorEnabled
        self.emailNotifications = emailNotifications
        self.smsAlerts = smsAlerts
        self.promoOffers = promoOffers
        self.emailVerifiedAt = emailVerifiedAt
        self.createdAt = createdAt
        self.title = title
        self.dob = dob
        self.nrc = nrc
        self.nationality = nationality
        self.passport = passport
        self.addressLine = addressLine
        self.township = township
        self.city = city
        self.region = region
    }

    static func fromJson(_ json: JSON) -> MemberAccount {
        MemberAccount(
            id: Dart.str(json["id"]) ?? "",
            publicId: Dart.str(json["publicId"]) ?? "",
            email: Dart.str(json["email"]) ?? "",
            phone: accountPhone(json),
            name: Dart.str(json["name"]) ?? "",
            role: Dart.str(json["role"]) ?? "",
            status: Dart.str(json["status"]) ?? "",
            tier: Dart.str(json["tier"]) ?? "",
            points: asInt(json["points"]),
            lifetimePoints: asInt(json["lifetimePoints"]),
            avatarUrl: Dart.str(json["avatarUrl"]) ?? "",
            twoFactorEnabled: asBool(json["twoFactorEnabled"]),
            emailNotifications: asBool(json["emailNotifications"]),
            smsAlerts: asBool(json["smsAlerts"]),
            promoOffers: asBool(json["promoOffers"]),
            emailVerifiedAt: DateTime.tryParse(Dart.str(json["emailVerifiedAt"]) ?? ""),
            createdAt: DateTime.tryParse(Dart.str(json["createdAt"]) ?? ""),
            title: Dart.str(json["title"]) ?? "",
            dob: DateTime.tryParse(Dart.str(json["dob"]) ?? ""),
            nrc: Dart.str(json["nrc"]) ?? "",
            nationality: Dart.str(json["nationality"]) ?? "",
            passport: Dart.str(json["passport"]) ?? "",
            addressLine: Dart.str(json["addressLine"]) ?? "",
            township: Dart.str(json["township"]) ?? "",
            city: Dart.str(json["city"]) ?? "",
            region: Dart.str(json["region"]) ?? ""
        )
    }
}

/// Account flags come back as a real boolean from `authSignin` but as the
/// string the client wrote (`SetMyTwoFactor` sends `'true'`) from `GetMe`, so
/// both spellings have to read as on — otherwise a saved toggle looks unsaved.
private func asBool(_ value: Any?) -> Bool {
    if let flag = Dart.bool(value) { return flag }
    if Dart.isNum(value) { return (Dart.double(value) ?? 0) != 0 }
    let text = Dart.str(value)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return text == "true" || text == "1" || text == "yes"
}

private func accountPhone(_ json: JSON) -> String {
    let candidates: [Any?] = [
        json["phone"],
        json["phoneNumber"],
        json["phoneNo"],
        json["mobile"],
        json["mobileNumber"],
        json["contactPhone"],
    ]
    // `a ?? b ?? …`: the first value that is not null.
    let value = candidates.first { !Dart.isNull($0) } ?? nil
    return Dart.str(value)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

/// One change in the member point balance returned by `GetMyPointLedger`.
struct PointLedgerTransaction {
    let id: String
    let type: String
    let points: Int
    let balanceAfter: Int
    let source: String
    let refId: String
    let note: String
    let createdAt: DateTime?
    let expiresAt: DateTime?
    let remainingPoints: Int
    let expiredAt: DateTime?

    init(
        id: String,
        type: String,
        points: Int,
        balanceAfter: Int,
        source: String,
        refId: String,
        note: String,
        createdAt: DateTime? = nil,
        expiresAt: DateTime? = nil,
        remainingPoints: Int,
        expiredAt: DateTime? = nil
    ) {
        self.id = id
        self.type = type
        self.points = points
        self.balanceAfter = balanceAfter
        self.source = source
        self.refId = refId
        self.note = note
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.remainingPoints = remainingPoints
        self.expiredAt = expiredAt
    }

    static func fromJson(_ json: JSON) -> PointLedgerTransaction {
        PointLedgerTransaction(
            id: Dart.str(json["id"]) ?? "",
            type: Dart.str(json["type"]) ?? "",
            points: asInt(json["points"]),
            balanceAfter: asInt(json["balanceAfter"]),
            source: Dart.str(json["source"]) ?? "",
            refId: Dart.str(json["refId"]) ?? "",
            note: Dart.str(json["note"]) ?? "",
            createdAt: DateTime.tryParse(Dart.str(json["createdAt"]) ?? ""),
            expiresAt: DateTime.tryParse(Dart.str(json["expiresAt"]) ?? ""),
            remainingPoints: asInt(json["remainingPoints"]),
            expiredAt: DateTime.tryParse(Dart.str(json["expiredAt"]) ?? "")
        )
    }
}

/// `num → toInt()`, `String → int.tryParse(text) ?? 0`, anything else → 0.
private func asInt(_ value: Any?) -> Int {
    if Dart.isNum(value) { return Dart.int(value) ?? 0 }
    if let text = Dart.unwrap(value) as? String { return Dart.parseInt(text) ?? 0 }
    return 0
}
