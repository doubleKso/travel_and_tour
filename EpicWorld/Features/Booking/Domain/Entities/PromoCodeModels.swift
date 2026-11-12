// Port of lib/features/booking/domain/entities/promo_code_models.dart

import Foundation

/// Request sent to the `checkPromoCode` callable before payment.
///
/// `HttpsCallable.call` wraps this payload in the Firebase callable `data`
/// envelope, so `toJson` deliberately contains only the inner request data.
struct PromoCodeCheckRequest: Hashable {
    let code: String
    let accessToken: String
    let subtotal: String
    let email: String

    init(code: String, accessToken: String, subtotal: String, email: String) {
        self.code = code
        self.accessToken = accessToken
        self.subtotal = subtotal
        self.email = email
    }

    func toJson() -> JSON {
        [
            "code": code,
            "accessToken": accessToken,
            "subtotal": subtotal,
            "email": email,
        ]
    }
}

/// Validated promotion details returned by `checkPromoCode`.
struct PromoCodeCheckResponse: Hashable {
    let ok: Bool
    let code: String
    let amount: Double
    let kind: String
    let value: Double
    let minSpend: Double
    let reason: String
    let message: String

    init(
        ok: Bool,
        code: String,
        amount: Double,
        kind: String,
        value: Double,
        minSpend: Double,
        reason: String,
        message: String
    ) {
        self.ok = ok
        self.code = code
        self.amount = amount
        self.kind = kind
        self.value = value
        self.minSpend = minSpend
        self.reason = reason
        self.message = message
    }

    static func fromJson(_ json: JSON) -> PromoCodeCheckResponse {
        PromoCodeCheckResponse(
            ok: Dart.bool(json["ok"]) == true,
            code: Dart.str(json["code"]) ?? "",
            amount: asDouble(json["amount"]),
            kind: Dart.str(json["kind"]) ?? "",
            value: asDouble(json["value"]),
            minSpend: asDouble(json["minSpend"]),
            reason: Dart.str(json["reason"]) ?? "",
            message: Dart.str(json["message"]) ?? ""
        )
    }

    /// Mirrors `fromJson` so an applied promotion can be written to storage and
    /// read back with the same badge ("20% off") the customer already saw.
    func toJson() -> JSON {
        [
            "ok": ok,
            "code": code,
            "amount": amount,
            "kind": kind,
            "value": value,
            "minSpend": minSpend,
            "reason": reason,
            "message": message,
        ]
    }

    /// Dart `switch (value) { num n => n.toDouble(), String t => double.tryParse(t) ?? 0, _ => 0 }`.
    private static func asDouble(_ value: Any?) -> Double {
        if Dart.isNum(value) { return Dart.double(value) ?? 0 }
        if let text = Dart.unwrap(value) as? String { return Dart.parseDouble(text) ?? 0 }
        return 0
    }
}
