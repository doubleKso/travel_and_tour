// Port of lib/features/ticket/domain/entities/booking_history_models.dart
import Foundation

/// A booking returned by the customer-facing `GetMyBookings` operation.
struct BookingHistoryItem {
    let id: String
    let reference: String
    let pnr: String
    let service: String
    let mode: String
    let tripType: String
    let cabin: String
    let adults: Int
    let children: Int
    let infants: Int
    let status: String
    let paymentMethod: String?
    let currency: String
    let route: String
    let perPaxFare: Double

    /// What was charged — already net of `promotion`.
    let total: Double

    /// Taken off by a promo code at checkout, 0 when none was used.
    let promotion: Double
    let contactFullName: String
    let contactTitle: String
    let contactCountryCode: String
    let contactPhone: String
    let contactEmail: String
    let bookingDeadline: DateTime?
    let createdAt: DateTime?
    let ticketedAt: DateTime?
    let ticketTimeLimit: DateTime?

    init(
        id: String,
        reference: String,
        pnr: String,
        service: String,
        mode: String,
        tripType: String,
        cabin: String,
        adults: Int,
        children: Int,
        infants: Int,
        status: String,
        paymentMethod: String?,
        currency: String,
        route: String,
        perPaxFare: Double,
        total: Double,
        promotion: Double = 0,
        contactFullName: String,
        contactTitle: String,
        contactCountryCode: String,
        contactPhone: String,
        contactEmail: String,
        bookingDeadline: DateTime?,
        createdAt: DateTime?,
        ticketedAt: DateTime?,
        ticketTimeLimit: DateTime?
    ) {
        self.id = id
        self.reference = reference
        self.pnr = pnr
        self.service = service
        self.mode = mode
        self.tripType = tripType
        self.cabin = cabin
        self.adults = adults
        self.children = children
        self.infants = infants
        self.status = status
        self.paymentMethod = paymentMethod
        self.currency = currency
        self.route = route
        self.perPaxFare = perPaxFare
        self.total = total
        self.promotion = promotion
        self.contactFullName = contactFullName
        self.contactTitle = contactTitle
        self.contactCountryCode = contactCountryCode
        self.contactPhone = contactPhone
        self.contactEmail = contactEmail
        self.bookingDeadline = bookingDeadline
        self.createdAt = createdAt
        self.ticketedAt = ticketedAt
        self.ticketTimeLimit = ticketTimeLimit
    }

    var passengerCount: Int { adults + children + infants }
    var isHeld: Bool { status.lowercased() == "held" }

    /// Only tickets the backend has issued may be presented as an e-ticket.
    /// Some older records have a populated `ticketedAt` but retain a legacy
    /// status, so accept either signal from the customer's own booking record.
    var isConfirmed: Bool {
        let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "confirmed"
            || normalized == "ticketed"
            || ticketedAt != nil
    }

    static func fromJson(_ json: JSON) -> BookingHistoryItem {
        BookingHistoryItem(
            id: Dart.str(json["id"]) ?? "",
            reference: Dart.str(json["reference"]) ?? "",
            pnr: Dart.str(json["pnr"]) ?? "",
            service: Dart.str(json["service"]) ?? "",
            mode: Dart.str(json["mode"]) ?? "",
            tripType: Dart.str(json["tripType"]) ?? "",
            cabin: Dart.str(json["cabin"]) ?? "",
            adults: bookingHistoryInt(json["adults"]),
            children: bookingHistoryInt(json["children"]),
            infants: bookingHistoryInt(json["infants"]),
            status: Dart.str(json["status"]) ?? "",
            paymentMethod: Dart.str(json["paymentMethod"]),
            currency: Dart.str(json["currency"]) ?? "MMK",
            route: Dart.str(json["route"]) ?? "",
            perPaxFare: bookingHistoryDouble(json["perPaxFare"]),
            total: bookingHistoryDouble(json["total"]),
            promotion: bookingHistoryDouble(json["promotion"]),
            contactFullName: Dart.str(json["contactFullName"]) ?? "",
            contactTitle: Dart.str(json["contactTitle"]) ?? "",
            contactCountryCode: Dart.str(json["contactCountryCode"]) ?? "",
            contactPhone: Dart.str(json["contactPhone"]) ?? "",
            contactEmail: Dart.str(json["contactEmail"]) ?? "",
            bookingDeadline: bookingHistoryDate(json["bookingDeadline"]),
            createdAt: bookingHistoryDate(json["createdAt"]),
            ticketedAt: bookingHistoryDate(json["ticketedAt"]),
            ticketTimeLimit: bookingHistoryDate(json["ticketTimeLimit"])
        )
    }
}

struct BookingHistorySegment {
    let direction: String
    let fromCode: String
    let toCode: String
    let fromCity: String
    let toCity: String
    let travelDate: String
    let departTime: String
    let arriveTime: String
    let flightNo: String
    let carrierName: String
    let cabin: String
    let stops: Int
    let baggageKg: Int
    let price: Double
    let refundable: Bool
    let fareBrand: String

    init(
        direction: String,
        fromCode: String,
        toCode: String,
        fromCity: String,
        toCity: String,
        travelDate: String,
        departTime: String,
        arriveTime: String,
        flightNo: String,
        carrierName: String,
        cabin: String,
        stops: Int,
        baggageKg: Int,
        price: Double,
        refundable: Bool,
        fareBrand: String
    ) {
        self.direction = direction
        self.fromCode = fromCode
        self.toCode = toCode
        self.fromCity = fromCity
        self.toCity = toCity
        self.travelDate = travelDate
        self.departTime = departTime
        self.arriveTime = arriveTime
        self.flightNo = flightNo
        self.carrierName = carrierName
        self.cabin = cabin
        self.stops = stops
        self.baggageKg = baggageKg
        self.price = price
        self.refundable = refundable
        self.fareBrand = fareBrand
    }

    static func fromJson(_ json: JSON) -> BookingHistorySegment {
        BookingHistorySegment(
            direction: Dart.str(json["direction"]) ?? "",
            fromCode: Dart.str(json["fromCode"]) ?? "",
            toCode: Dart.str(json["toCode"]) ?? "",
            fromCity: Dart.str(json["fromCity"]) ?? "",
            toCity: Dart.str(json["toCity"]) ?? "",
            travelDate: Dart.str(json["travelDate"]) ?? "",
            departTime: Dart.str(json["departTime"]) ?? "",
            arriveTime: Dart.str(json["arriveTime"]) ?? "",
            flightNo: Dart.str(json["flightNo"]) ?? "",
            carrierName: Dart.str(json["carrierName"]) ?? "",
            cabin: Dart.str(json["cabin"]) ?? "",
            stops: bookingHistoryInt(json["stops"]),
            baggageKg: bookingHistoryInt(json["baggageKg"]),
            price: bookingHistoryDouble(json["price"]),
            refundable: Dart.bool(json["refundable"]) == true,
            fareBrand: Dart.str(json["fareBrand"]) ?? ""
        )
    }
}

struct BookingHistoryPassenger {
    let title: String
    let firstName: String
    let lastName: String
    let type: String
    let gender: String
    let dob: String
    let nationality: String
    let nrc: String
    let passportNo: String

    init(
        title: String,
        firstName: String,
        lastName: String,
        type: String,
        gender: String,
        dob: String,
        nationality: String,
        nrc: String,
        passportNo: String
    ) {
        self.title = title
        self.firstName = firstName
        self.lastName = lastName
        self.type = type
        self.gender = gender
        self.dob = dob
        self.nationality = nationality
        self.nrc = nrc
        self.passportNo = passportNo
    }

    var fullName: String {
        "\(title) \(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func fromJson(_ json: JSON) -> BookingHistoryPassenger {
        BookingHistoryPassenger(
            title: Dart.str(json["title"]) ?? "",
            firstName: Dart.str(json["firstName"]) ?? "",
            lastName: Dart.str(json["lastName"]) ?? "",
            type: Dart.str(json["type"]) ?? "",
            gender: Dart.str(json["gender"]) ?? "",
            dob: Dart.str(json["dob"]) ?? "",
            nationality: Dart.str(json["nationality"]) ?? "",
            nrc: Dart.str(json["nrc"]) ?? "",
            passportNo: Dart.str(json["passportNo"]) ?? ""
        )
    }
}

struct BookingHistoryDetail {
    let segments: [BookingHistorySegment]
    let passengers: [BookingHistoryPassenger]

    init(segments: [BookingHistorySegment], passengers: [BookingHistoryPassenger]) {
        self.segments = segments
        self.passengers = passengers
    }
}

// Dart's file-private `_int` / `_double` / `_date`.

/// `value is num ? value.toInt() : 0`
private func bookingHistoryInt(_ value: Any?) -> Int { Dart.int(value) ?? 0 }

/// `value is num ? value.toDouble() : 0`
private func bookingHistoryDouble(_ value: Any?) -> Double { Dart.double(value) ?? 0 }

/// `value == null ? null : DateTime.tryParse(value.toString())`
private func bookingHistoryDate(_ value: Any?) -> DateTime? {
    guard let text = Dart.str(value) else { return nil }
    return DateTime.tryParse(text)
}
