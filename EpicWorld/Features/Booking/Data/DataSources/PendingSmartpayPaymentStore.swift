// Port of lib/features/booking/data/datasources/pending_smartpay_payment_store.dart

import Foundation

/// The minimum non-secret context needed to pick a payment back up.
///
/// SmartPay's return URL is a web address, so on Flutter web it starts a fresh
/// app instance with none of the booking in memory; on mobile the app can be
/// evicted while the customer is in a wallet app. Neither the access token nor
/// anything else secret is kept here — only what `GetPaymentStatusRequest`
/// needs to ask the backend what happened.
struct PendingSmartPayPayment: Hashable {
    let reference: String
    let email: String
    let merchantOrderNo: String
    let startedAt: DateTime

    init(reference: String, email: String, merchantOrderNo: String, startedAt: DateTime) {
        self.reference = reference
        self.email = email
        self.merchantOrderNo = merchantOrderNo
        self.startedAt = startedAt
    }

    func toJson() -> JSON {
        [
            "reference": reference,
            "email": email,
            "merchantOrderNo": merchantOrderNo,
            "startedAt": startedAt.toUtc().toIso8601String(),
        ]
    }

    static func fromJson(_ json: JSON) -> PendingSmartPayPayment {
        let startedAt = DateTime.tryParse(Dart.str(json["startedAt"]) ?? "")
        return PendingSmartPayPayment(
            reference: Dart.str(json["reference"]) ?? "",
            email: Dart.str(json["email"]) ?? "",
            merchantOrderNo: Dart.str(json["merchantOrderNo"]) ?? "",
            startedAt: startedAt ?? DateTime.now().toUtc()
        )
    }
}

enum PendingSmartPayPaymentStore {
    private static let key = "booking.pending_smartpay_payment"

    /// The payment awaiting verification, or null when there is none worth
    /// asking about (nothing stored, or a record too damaged to use).
    static func read() -> PendingSmartPayPayment? {
        let value = AppPrefs.getString(key).trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return nil }
        guard let decoded = try? jsonDecode(value), let json = Dart.map(decoded) else { return nil }
        let pending = PendingSmartPayPayment.fromJson(json)
        if pending.reference.isEmpty || pending.email.isEmpty { return nil }
        return pending
    }

    static func save(_ payment: PendingSmartPayPayment) async {
        AppPrefs.setString(key, jsonEncode(payment.toJson()))
    }

    static func clear() async {
        AppPrefs.remove(key)
    }
}
