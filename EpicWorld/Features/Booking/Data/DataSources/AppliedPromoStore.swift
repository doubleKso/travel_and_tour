// Port of lib/features/booking/data/datasources/applied_promo_store.dart

import Foundation

/// A promotion the customer has already applied on the payment screen.
///
/// Tied to the reservation it was validated against: a promo checked for one
/// booking reference must never reappear as a discount on another.
struct AppliedPromo: Hashable {
    /// Booking reference (the `holdFlight` reference) this promotion belongs to.
    let reference: String

    /// The code as the backend returned it, which is what gets sent on to
    /// `createPaymentIntent`.
    let code: String

    /// Discount in the booking's currency, as shown in the amount summary.
    let discount: Double

    /// The validated response, kept whole so the restored screen shows the same
    /// badge ("20% off") rather than a flattened version of it.
    let promo: PromoCodeCheckResponse

    init(reference: String, code: String, discount: Double, promo: PromoCodeCheckResponse) {
        self.reference = reference
        self.code = code
        self.discount = discount
        self.promo = promo
    }

    func toJson() -> JSON {
        [
            "reference": reference,
            "code": code,
            "discount": discount,
            "promo": promo.toJson(),
        ]
    }

    static func fromJson(_ json: JSON) -> AppliedPromo {
        let discount: Double
        if Dart.isNum(json["discount"]) {
            discount = Dart.double(json["discount"]) ?? 0
        } else if let text = Dart.unwrap(json["discount"]) as? String {
            discount = Dart.parseDouble(text) ?? 0
        } else {
            discount = 0
        }
        return AppliedPromo(
            reference: Dart.str(json["reference"]) ?? "",
            code: Dart.str(json["code"]) ?? "",
            discount: discount,
            promo: PromoCodeCheckResponse.fromJson(Dart.map(json["promo"]) ?? [:])
        )
    }
}

/// Keeps an applied promotion attached to its booking across a reload.
///
/// The payment screen's state does not survive leaving for SmartPay's hosted
/// checkout — on web that redirect is a cold app start, and on mobile the
/// screen can be rebuilt or the app evicted — and re-typing a working promo
/// code afterwards is a poor way to be sent back to a payment form.
enum AppliedPromoStore {
    private static let key = "booking.applied_promo"

    /// The promotion stored for `reference`, or null when there is none, the
    /// record is for a different booking, or it is too damaged to trust.
    ///
    /// Scoping the read by reference is what stops a promo from following the
    /// customer onto their next booking.
    static func read(_ reference: String) -> AppliedPromo? {
        let wanted = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        if wanted.isEmpty { return nil }
        let value = AppPrefs.getString(key).trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return nil }
        guard let decoded = try? jsonDecode(value), let json = Dart.map(decoded) else { return nil }
        let applied = AppliedPromo.fromJson(json)
        if applied.reference != wanted { return nil }
        if applied.code.isEmpty || !applied.promo.ok { return nil }
        return applied
    }

    static func save(_ applied: AppliedPromo) async {
        AppPrefs.setString(key, jsonEncode(applied.toJson()))
    }

    static func clear() async {
        AppPrefs.remove(key)
    }
}
