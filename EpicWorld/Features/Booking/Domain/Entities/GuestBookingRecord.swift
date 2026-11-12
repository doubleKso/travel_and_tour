// Port of lib/features/booking/domain/entities/guest_booking_record.dart

import Foundation

/// The device's own memory of a booking made without signing in.
///
/// A guest has no account for the server to hang history off, so the only
/// thread back to a reservation is the pair the backend keys on — the `EW-`
/// reference and the contact email. Both live here, alongside just enough of
/// the booking to draw a history row before the server has been asked
/// anything. Everything in this record is display cache except `reference` and
/// `email`; `listGuestBookings` refreshes the rest.
struct GuestBookingRecord: Hashable {
    let reference: String
    let email: String

    /// `RGN → BKK`, as shown on the card.
    let route: String

    /// `flight` today; the field exists so hotel/tour holds can join later.
    let service: String

    /// Departure day as `yyyy-MM-dd`.
    let travelDate: String

    /// When this device first stored the booking.
    let savedAt: DateTime

    /// Deadline for paying before the airline releases the seats.
    let ticketTimeLimit: DateTime?

    let amount: Double
    let currency: String

    /// One of `GuestBookingStatus`.
    let status: String

    /// Airline reference, known only once the server has been asked.
    let pnr: String

    init(
        reference: String,
        email: String,
        route: String,
        service: String,
        travelDate: String,
        savedAt: DateTime,
        ticketTimeLimit: DateTime?,
        amount: Double,
        currency: String,
        status: String,
        pnr: String = ""
    ) {
        self.reference = reference
        self.email = email
        self.route = route
        self.service = service
        self.travelDate = travelDate
        self.savedAt = savedAt
        self.ticketTimeLimit = ticketTimeLimit
        self.amount = amount
        self.currency = currency
        self.status = status
        self.pnr = pnr
    }

    var isPendingPayment: Bool { status == GuestBookingStatus.pendingPayment }

    /// How long is left to pay, or null when the booking carries no deadline.
    var timeLeft: Duration? {
        guard let limit = ticketTimeLimit else { return nil }
        let left = limit.difference(DateTime.now())
        return left.isNegative ? .zero : left
    }

    /// A hold whose deadline has passed. Payment is refused server-side from
    /// here on, so the row stops offering it.
    var isExpired: Bool {
        status == GuestBookingStatus.expired || (isPendingPayment && timeLeft == Duration.zero)
    }

    /// Only a live hold can still be paid.
    var isPayable: Bool { isPendingPayment && !isExpired }

    /// `sjbudv0wrv@gmail.com` → `s•••••@gmail.com`.
    ///
    /// The card is drawn on a device that may be shared, and the full address is
    /// half of what it takes to open the booking.
    var maskedEmail: String {
        guard let at = email.firstIndex(of: "@"), at != email.startIndex else { return email }
        return "\(email[email.startIndex])•••••\(email[at...])"
    }

    func copyWith(
        route: String? = nil,
        travelDate: String? = nil,
        ticketTimeLimit: DateTime? = nil,
        amount: Double? = nil,
        currency: String? = nil,
        status: String? = nil,
        pnr: String? = nil
    ) -> GuestBookingRecord {
        GuestBookingRecord(
            reference: reference,
            email: email,
            route: route ?? self.route,
            service: service,
            travelDate: travelDate ?? self.travelDate,
            savedAt: savedAt,
            ticketTimeLimit: ticketTimeLimit ?? self.ticketTimeLimit,
            amount: amount ?? self.amount,
            currency: currency ?? self.currency,
            status: status ?? self.status,
            pnr: pnr ?? self.pnr
        )
    }

    func toJson() -> JSON {
        [
            "reference": reference,
            "email": email,
            "route": route,
            "service": service,
            "travelDate": travelDate,
            "savedAt": savedAt.toUtc().toIso8601String(),
            "ticketTimeLimit": ticketTimeLimit?.toUtc().toIso8601String() ?? "",
            "amount": amount,
            "currency": currency,
            "status": status,
            "pnr": pnr,
        ]
    }

    static func fromJson(_ json: JSON) -> GuestBookingRecord {
        let status = Dart.str(json["status"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return GuestBookingRecord(
            reference: Dart.str(json["reference"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            email: Dart.str(json["email"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            route: Dart.str(json["route"]) ?? "",
            service: Dart.str(json["service"]) ?? "flight",
            travelDate: Dart.str(json["travelDate"]) ?? "",
            savedAt: DateTime.tryParse(Dart.str(json["savedAt"]) ?? "")?.toLocal() ?? DateTime.now(),
            ticketTimeLimit: DateTime.tryParse(Dart.str(json["ticketTimeLimit"]) ?? "")?.toLocal(),
            amount: double(json["amount"]),
            currency: Dart.str(json["currency"]) ?? "MMK",
            status: !status.isEmpty ? status : GuestBookingStatus.pendingPayment,
            pnr: Dart.str(json["pnr"]) ?? ""
        )
    }

    private static func double(_ value: Any?) -> Double {
        Dart.isNum(value)
            ? (Dart.double(value) ?? 0)
            : Dart.parseDouble(Dart.str(value) ?? "") ?? 0
    }
}

/// The statuses a stored guest booking can hold.
///
/// Deliberately the app's own vocabulary rather than the server's: the record
/// is written the moment the seats are held, before any server status exists,
/// and `fromServer` folds the backend's wording into it on every refresh.
enum GuestBookingStatus {
    static let pendingPayment = "pending_payment"
    static let confirmed = "confirmed"
    static let expired = "expired"
    static let cancelled = "cancelled"

    static func fromServer(_ status: String, ticketed: Bool = false) -> String {
        if ticketed { return confirmed }
        switch status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "ticketed", "issued", "confirmed", "paid":
            return confirmed
        case "cancelled", "canceled", "void", "voided":
            return cancelled
        case "expired":
            return expired
        default:
            return pendingPayment
        }
    }

    /// Short label for the status chip on a history card.
    static func label(_ record: GuestBookingRecord) -> String {
        if record.status == confirmed { return "Confirmed" }
        if record.status == cancelled { return "Cancelled" }
        if record.isExpired { return "Hold expired" }
        return "Seats held"
    }
}
