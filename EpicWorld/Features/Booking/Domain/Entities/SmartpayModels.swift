// Port of lib/features/booking/domain/entities/smartpay_models.dart

import Foundation

/// Request sent to the `createPaymentIntent` callable.
///
/// `HttpsCallable.call` supplies Firebase's outer `data` envelope, so this
/// model represents only the payload inside it.
struct CreatePaymentIntentRequest: Hashable {
    let reference: String
    let accessToken: String
    let email: String
    let promoCode: String

    init(reference: String, accessToken: String, email: String, promoCode: String = "") {
        self.reference = reference
        self.accessToken = accessToken
        self.email = email
        self.promoCode = promoCode
    }

    func toJson() -> JSON {
        [
            "reference": reference,
            "accessToken": accessToken,
            "email": email,
            "promoCode": promoCode,
        ]
    }
}

/// Hosted-payment details returned by `createPaymentIntent`.
struct CreatePaymentIntentResponse: Hashable {
    let ok: Bool
    let paymentUrl: String
    let merchantOrderNo: String
    let amount: Double
    let currency: String
    let payBefore: String
    let reason: String
    let message: String

    init(
        ok: Bool,
        paymentUrl: String,
        merchantOrderNo: String,
        amount: Double,
        currency: String,
        payBefore: String,
        reason: String,
        message: String
    ) {
        self.ok = ok
        self.paymentUrl = paymentUrl
        self.merchantOrderNo = merchantOrderNo
        self.amount = amount
        self.currency = currency
        self.payBefore = payBefore
        self.reason = reason
        self.message = message
    }

    static func fromJson(_ json: JSON) -> CreatePaymentIntentResponse {
        CreatePaymentIntentResponse(
            ok: Dart.bool(json["ok"]) == true,
            paymentUrl: Dart.str(json["paymentUrl"]) ?? "",
            merchantOrderNo: Dart.str(json["merchantOrderNo"]) ?? "",
            amount: smartPayAsDouble(json["amount"]),
            currency: Dart.str(json["currency"]) ?? "",
            payBefore: Dart.str(json["payBefore"]) ?? "",
            reason: Dart.str(json["reason"]) ?? "",
            message: Dart.str(json["message"]) ?? ""
        )
    }

    /// The backend's reason for refusing, preferring whichever field it filled.
    var failureMessage: String {
        for value in [message, reason] {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return "SmartPay did not return a payment link."
    }
}

/// Request sent to `getPaymentStatus` once the hosted page hands the customer
/// back.
struct GetPaymentStatusRequest: Hashable {
    let reference: String
    let accessToken: String
    let email: String

    init(reference: String, accessToken: String, email: String) {
        self.reference = reference
        self.accessToken = accessToken
        self.email = email
    }

    func toJson() -> JSON {
        [
            "reference": reference,
            "accessToken": accessToken,
            "email": email,
        ]
    }
}

/// Server-verified payment and ticketing state returned by `getPaymentStatus`.
///
/// This is the app's only proof that a payment happened. SmartPay reports the
/// charge to the backend through its own `smartpayCallback` webhook, which the
/// client never calls and never sees; whatever the return URL puts in its
/// query string is decoration.
struct GetPaymentStatusResponse: Hashable {
    let ok: Bool
    let status: String
    let bookingStatus: String
    let ticketed: Bool
    let amount: Double
    let currency: String
    let merchantOrderNo: String
    let providerCode: String
    let failureReason: String
    let payBefore: String
    let reason: String
    let message: String

    init(
        ok: Bool,
        status: String,
        bookingStatus: String,
        ticketed: Bool,
        amount: Double,
        currency: String,
        merchantOrderNo: String,
        providerCode: String,
        failureReason: String,
        payBefore: String,
        reason: String,
        message: String
    ) {
        self.ok = ok
        self.status = status
        self.bookingStatus = bookingStatus
        self.ticketed = ticketed
        self.amount = amount
        self.currency = currency
        self.merchantOrderNo = merchantOrderNo
        self.providerCode = providerCode
        self.failureReason = failureReason
        self.payBefore = payBefore
        self.reason = reason
        self.message = message
    }

    static func fromJson(_ json: JSON) -> GetPaymentStatusResponse {
        GetPaymentStatusResponse(
            ok: Dart.bool(json["ok"]) == true,
            status: Dart.str(json["status"]) ?? "",
            bookingStatus: Dart.str(json["bookingStatus"]) ?? "",
            ticketed: Dart.bool(json["ticketed"]) == true,
            amount: smartPayAsDouble(json["amount"]),
            currency: Dart.str(json["currency"]) ?? "",
            merchantOrderNo: Dart.str(json["merchantOrderNo"]) ?? "",
            providerCode: Dart.str(json["providerCode"]) ?? "",
            failureReason: Dart.str(json["failureReason"]) ?? "",
            payBefore: Dart.str(json["payBefore"]) ?? "",
            reason: Dart.str(json["reason"]) ?? "",
            message: Dart.str(json["message"]) ?? ""
        )
    }

    var normalizedStatus: String {
        status.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    /// Complete only once the backend has both settled the charge and issued the
    /// ticket. A paid-but-not-yet-ticketed booking is still in flight, and
    /// showing a boarding pass for one would be a lie.
    var isSuccessful: Bool { ok && normalizedStatus == "PAID" && ticketed }

    /// States SmartPay will not move out of. Anything else is worth polling for.
    var isTerminalFailure: Bool {
        ["FAILED", "EXPIRED", "CANCELLED", "CLOSED"].contains(normalizedStatus)
    }

    /// The customer left SmartPay before it completed a charge. It is safe to
    /// offer the hosted checkout again for this same held booking; the backend
    /// remains responsible for refusing an expired, cancelled, or paid booking.
    var canResumePayment: Bool { ok && normalizedStatus == "PENDING" }

    var displayMessage: String {
        for value in [failureReason, message, reason] {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        if normalizedStatus == "PAID" && !ticketed {
            return "Payment was received and ticketing is still in progress."
        }
        return "Payment is still pending."
    }
}

/// Dart's file-private `_asDouble`: `num` → double, `String` → `double.tryParse`, else 0.
private func smartPayAsDouble(_ value: Any?) -> Double {
    if Dart.isNum(value) { return Dart.double(value) ?? 0 }
    if let text = Dart.unwrap(value) as? String { return Dart.parseDouble(text) ?? 0 }
    return 0
}
