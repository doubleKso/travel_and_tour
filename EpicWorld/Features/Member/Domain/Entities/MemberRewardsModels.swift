// Port of lib/features/member/domain/entities/member_rewards_models.dart
import Foundation

/// A deposit discount tier returned by `GetDiscountTiers`.
struct DiscountTier {
    let id: String
    let code: String
    let name: String
    let ratePct: Double
    let active: Bool
    let minDeposit: Double

    init(id: String, code: String, name: String, ratePct: Double, active: Bool, minDeposit: Double) {
        self.id = id
        self.code = code
        self.name = name
        self.ratePct = ratePct
        self.active = active
        self.minDeposit = minDeposit
    }

    static func fromJson(_ json: JSON) -> DiscountTier {
        DiscountTier(
            id: Dart.str(json["id"]) ?? "",
            code: Dart.str(json["code"]) ?? "",
            name: Dart.str(json["name"]) ?? "",
            ratePct: asDouble(json["ratePct"]),
            active: Dart.bool(json["active"]) == true,
            minDeposit: asDouble(json["minDeposit"])
        )
    }
}

/// The signed-in member's currently redeemable point balance.
///
/// `myPoints` has shipped a few equivalent balance keys across environments,
/// so the parser accepts those aliases while exposing one stable value to the
/// rest of the app.
struct MemberPointBalance {
    let points: Int

    init(points: Int) {
        self.points = points
    }

    /// `const MemberPointBalance.empty()`.
    static func empty() -> MemberPointBalance { MemberPointBalance(points: 0) }

    static func fromJson(_ json: JSON) -> MemberPointBalance {
        let source = Dart.map(json["data"]) ?? json
        for key in [
            "points",
            "balance",
            "availablePoints",
            "pointBalance",
            "totalPoints",
        ] {
            if let parsed = asInt(source[key]) { return MemberPointBalance(points: parsed) }
        }
        return .empty()
    }
}

/// Inner Firebase callable payload for `/redeemPoints`.
struct RedeemPointsRequest {
    let accessToken: String
    let bookingId: String
    let points: String

    init(accessToken: String, bookingId: String, points: String) {
        self.accessToken = accessToken
        self.bookingId = bookingId
        self.points = points
    }

    func toJson() -> JSON {
        [
            "accessToken": accessToken,
            "bookingId": bookingId,
            "points": points,
        ]
    }
}

/// Authoritative result after points are applied to a held booking.
struct RedeemPointsResponse {
    let ok: Bool
    let redeemed: Int
    let discount: Double
    let balance: Int

    init(ok: Bool, redeemed: Int, discount: Double, balance: Int) {
        self.ok = ok
        self.redeemed = redeemed
        self.discount = discount
        self.balance = balance
    }

    static func fromJson(_ json: JSON) -> RedeemPointsResponse {
        RedeemPointsResponse(
            ok: Dart.bool(json["ok"]) == true,
            redeemed: asInt(json["redeemed"]) ?? 0,
            discount: asDouble(json["discount"]),
            balance: asInt(json["balance"]) ?? 0
        )
    }
}

/// `num → toDouble()`, `String → double.tryParse(text) ?? 0`, anything else → 0.
private func asDouble(_ value: Any?) -> Double {
    if Dart.isNum(value) { return Dart.double(value) ?? 0 }
    if let text = Dart.unwrap(value) as? String { return Dart.parseDouble(text) ?? 0 }
    return 0
}

/// `num → toInt()`, `String → int.tryParse(text)`, anything else → null.
private func asInt(_ value: Any?) -> Int? {
    if Dart.isNum(value) { return Dart.int(value) }
    if let text = Dart.unwrap(value) as? String { return Dart.parseInt(text) }
    return nil
}
