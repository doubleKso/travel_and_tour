// Port of lib/features/booking/domain/entities/guest_booking_models.dart

import Foundation

/// One row of `listGuestBookings` — the server's current word on a booking
/// this device remembers.
///
/// Deliberately thinner than `BookingHistoryItem`: the guest endpoint answers
/// only what a history card needs, and asks for no session in return.
struct GuestBookingSummary: Hashable {
    let reference: String
    let status: String
    let mode: String
    let route: String
    let total: Double
    let currency: String
    let pnr: String
    let ticketed: Bool
    let ticketTimeLimit: DateTime?
    let bookingDeadline: DateTime?
    let createdAt: DateTime?

    init(
        reference: String,
        status: String,
        mode: String,
        route: String,
        total: Double,
        currency: String,
        pnr: String,
        ticketed: Bool,
        ticketTimeLimit: DateTime?,
        bookingDeadline: DateTime?,
        createdAt: DateTime?
    ) {
        self.reference = reference
        self.status = status
        self.mode = mode
        self.route = route
        self.total = total
        self.currency = currency
        self.pnr = pnr
        self.ticketed = ticketed
        self.ticketTimeLimit = ticketTimeLimit
        self.bookingDeadline = bookingDeadline
        self.createdAt = createdAt
    }

    static func fromJson(_ json: JSON) -> GuestBookingSummary {
        GuestBookingSummary(
            reference: Dart.str(json["reference"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            status: Dart.str(json["status"]) ?? "",
            mode: Dart.str(json["mode"]) ?? "",
            route: Dart.str(json["route"]) ?? "",
            total: double(json["total"]),
            currency: Dart.str(json["currency"]) ?? "MMK",
            pnr: Dart.str(json["pnr"]) ?? "",
            ticketed: Dart.bool(json["ticketed"]) == true,
            ticketTimeLimit: date(json["ticketTimeLimit"]),
            bookingDeadline: date(json["bookingDeadline"]),
            createdAt: date(json["createdAt"])
        )
    }

    private static func double(_ value: Any?) -> Double {
        Dart.isNum(value)
            ? (Dart.double(value) ?? 0)
            : Dart.parseDouble(Dart.str(value) ?? "") ?? 0
    }

    private static func date(_ value: Any?) -> DateTime? {
        let text = Dart.str(value)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.isEmpty { return nil }
        return DateTime.tryParse(text)?.toLocal()
    }
}

/// The full answer from `findGuestBooking`: the booking, its legs and its
/// travellers, which together are enough to rebuild the checkout.
struct GuestBookingLookup {
    let ok: Bool
    let reason: String
    let message: String
    let booking: BookingHistoryItem?
    let segments: [BookingHistorySegment]
    let passengers: [BookingHistoryPassenger]

    init(
        ok: Bool,
        reason: String,
        message: String,
        booking: BookingHistoryItem?,
        segments: [BookingHistorySegment],
        passengers: [BookingHistoryPassenger]
    ) {
        self.ok = ok
        self.reason = reason
        self.message = message
        self.booking = booking
        self.segments = segments
        self.passengers = passengers
    }

    /// `contactEmail` fills in for a booking record that carries no contact of
    /// its own — the address the customer just searched with is the one the
    /// server matched, so it is the right one to confirm and pay against.
    static func fromJson(_ json: JSON, contactEmail: String = "") -> GuestBookingLookup {
        var bookingJson = first(json["booking"])
        if var booking = bookingJson,
           (Dart.str(booking["contactEmail"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty,
           !contactEmail.isEmpty {
            booking["contactEmail"] = contactEmail
            bookingJson = booking
        }
        return GuestBookingLookup(
            ok: Dart.bool(json["ok"]) != false,
            reason: Dart.str(json["reason"]) ?? "",
            message: Dart.str(json["message"]) ?? "",
            booking: bookingJson.map { BookingHistoryItem.fromJson($0) },
            segments: list(json["segments"]).map { BookingHistorySegment.fromJson($0) },
            passengers: list(json["passengers"]).map { BookingHistoryPassenger.fromJson($0) }
        )
    }

    /// Accepts every shape the callables use for a collection: a bare list, a
    /// single object, or an object wrapping one list (`{"segments": [...]}`).
    static func list(_ value: Any?) -> [JSON] {
        if Dart.isList(value) {
            return Dart.maps(value)
        }
        if let map = Dart.map(value) {
            // Dart iterates a decoded map in its JSON key order; a wrapper
            // object carries a single list, so the first one found is it.
            if let nested = map.values.first(where: { Dart.isList($0) }) { return list(nested) }
            return map.isEmpty ? [] : [map]
        }
        return []
    }

    private static func first(_ value: Any?) -> JSON? {
        let items = list(value)
        return items.isEmpty ? nil : items.first
    }
}
