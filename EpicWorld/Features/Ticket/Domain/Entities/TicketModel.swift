// Port of lib/features/ticket/domain/entities/ticket_model.dart
import Foundation

/// One traveller on a ticket, as they were entered on the Traveller
/// Information form and sent to `holdFlight`.
///
/// The e-ticket prints these verbatim: a passport number or phone that does
/// not match what the customer typed is worse than useless at a check-in desk.
struct TicketPassenger: Hashable {
    let title: String
    let firstName: String
    let lastName: String

    /// adult / child / infant, as the fare was priced.
    let type: String
    let nrc: String
    let passportNo: String

    /// Booking contact phone, including its country code.
    let phone: String

    /// Airline ticket number, empty until the backend reports one. Never
    /// invented locally — a made-up number on a travel document is a liability.
    let ticketNumber: String

    init(
        title: String = "",
        firstName: String = "",
        lastName: String = "",
        type: String = "",
        nrc: String = "",
        passportNo: String = "",
        phone: String = "",
        ticketNumber: String = ""
    ) {
        self.title = title
        self.firstName = firstName
        self.lastName = lastName
        self.type = type
        self.nrc = nrc
        self.passportNo = passportNo
        self.phone = phone
        self.ticketNumber = ticketNumber
    }

    /// Builds a traveller from the `passengers` entry of a `holdFlight` request.
    /// `phone` comes from the booking contact, which the form collects once for
    /// the whole reservation rather than per traveller.
    static func fromHoldRequest(
        _ passenger: JSON,
        phone: String = "",
        ticketNumber: String = ""
    ) -> TicketPassenger {
        func field(_ key: String) -> String {
            Dart.str(passenger[key])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        return TicketPassenger(
            title: field("title"),
            firstName: field("firstName"),
            lastName: field("lastName"),
            type: field("type"),
            nrc: field("nrc"),
            passportNo: field("passportNo"),
            phone: phone,
            ticketNumber: ticketNumber
        )
    }

    var fullName: String {
        [title, firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// The travel document to print: the passport if there is one, otherwise the
    /// NRC that domestic travellers give instead.
    var documentNumber: String { !passportNo.isEmpty ? passportNo : nrc }
}

/// A purchased ticket. Drives both the "Tickets" (active) and "History" tabs.
struct TicketModel {
    let id: String
    /// PNR / booking code, also encoded in the QR
    let bookingReference: String

    /// The airline's own PNR (e.g. `17T1EK`), as opposed to Epic World's
    /// `bookingReference`. Empty when the airline hasn't reported one.
    let pnr: String

    /// Who made the booking — the contact on the booking form, printed beside
    /// "Booked by". Empty when it isn't known.
    let contactName: String
    let outbound: TripOptionModel
    /// nil for one-way
    let inbound: TripOptionModel?
    let passengerName: String
    let seatCount: Int

    /// Everyone travelling on this booking, in the order they were entered.
    ///
    /// Empty on tickets created before travellers were carried through (and on
    /// the mock catalogue), which is why the e-ticket falls back to `seatCount`
    /// and `passengerName` rather than assuming this is populated.
    let passengers: [TicketPassenger]

    /// What was charged — already net of `discount`.
    let totalPaid: Double

    /// Taken off the fare at checkout: the promo code's discount, or the value
    /// of redeemed reward points. 0 when neither was used or it isn't known.
    let discount: Double

    /// The part of `discount` a promo code took off, 0 when no promo was used.
    /// Kept apart so the e-ticket can label it as a promo even when the code
    /// itself isn't known (History's booking records only keep the amount).
    let promotion: Double

    /// Promo code applied at checkout, empty when none was used.
    let promoCode: String
    let currency: String
    let issuedAt: DateTime

    /// Raw payload encoded into the validation QR (usually a signed token, not
    /// just the PNR — see the QR notes in the project docs).
    let qrPayload: String

    /// True when this is an unpaid **reservation** rather than a paid e-ticket.
    /// Non-MAI airlines can only be reserved (not bought in-app) — the customer
    /// completes payment at the office — so those bookings land here.
    let isReservation: Bool

    // Contact details collected on the reservation ("Booking Form") screen —
    // only populated for reservations, nil for paid e-tickets.
    let phone: String?
    let email: String?
    let message: String?

    init(
        id: String,
        bookingReference: String,
        outbound: TripOptionModel,
        inbound: TripOptionModel?,
        passengerName: String,
        seatCount: Int,
        totalPaid: Double,
        currency: String,
        issuedAt: DateTime,
        qrPayload: String,
        pnr: String = "",
        contactName: String = "",
        passengers: [TicketPassenger] = [],
        discount: Double = 0,
        promotion: Double = 0,
        promoCode: String = "",
        isReservation: Bool = false,
        phone: String? = nil,
        email: String? = nil,
        message: String? = nil
    ) {
        self.id = id
        self.bookingReference = bookingReference
        self.outbound = outbound
        self.inbound = inbound
        self.passengerName = passengerName
        self.seatCount = seatCount
        self.totalPaid = totalPaid
        self.currency = currency
        self.issuedAt = issuedAt
        self.qrPayload = qrPayload
        self.pnr = pnr
        self.contactName = contactName
        self.passengers = passengers
        self.discount = discount
        self.promotion = promotion
        self.promoCode = promoCode
        self.isReservation = isReservation
        self.phone = phone
        self.email = email
        self.message = message
    }

    var tripDate: DateTime { outbound.departure }

    /// Active = the (first) departure is still in the future.
    func isActive(_ now: DateTime) -> Bool { outbound.departure.isAfter(now) }

    /// Time remaining until departure — powers the countdown on the Tickets tab.
    func timeUntilDeparture(_ now: DateTime) -> Duration {
        outbound.departure.difference(now)
    }
}
