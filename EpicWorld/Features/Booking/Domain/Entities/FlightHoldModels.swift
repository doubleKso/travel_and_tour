// Port of lib/features/booking/domain/entities/flight_hold_models.dart

import Foundation

/// Payload sent to the `holdFlight` callable when a reservation is submitted.
struct FlightHoldRequest {
    /// Idempotency key for this submission (a v4 UUID). It is fixed when the
    /// request is built, so a retry of the same request — e.g. after a token
    /// refresh — cannot create a second hold.
    let requestKey: String
    let selections: [JSON]
    let passengers: [JSON]
    let contact: JSON
    let paymentMethod: String?
    let acceptPriceChange: Bool

    init(
        requestKey: String? = nil,
        selections: [JSON],
        passengers: [JSON],
        contact: JSON,
        paymentMethod: String? = nil,
        acceptPriceChange: Bool = false
    ) {
        self.requestKey = requestKey ?? UUID().uuidString.lowercased()
        self.selections = selections
        self.passengers = passengers
        self.contact = contact
        self.paymentMethod = paymentMethod
        self.acceptPriceChange = acceptPriceChange
    }

    /// Guests may hold a flight as long as they supply the required contact and
    /// traveller details. Authenticated users include their token when present.
    func toJson(accessToken: String? = nil) -> JSON {
        [
            "requestKey": requestKey,
            "selections": selections,
            "passengers": passengers,
            "contact": contact,
            "paymentMethod": (paymentMethod as Any?) ?? NSNull(),
            "acceptPriceChange": acceptPriceChange,
            "accessToken": (accessToken as Any?) ?? NSNull(),
        ]
    }

    static func selectionFrom(_ option: TripOptionModel) -> JSON {
        [
            "from": option.originCode,
            "to": option.destinationCode,
            "departDate": dateOnly(option.departure),
            "departAt": myanmarDateTime(option.departure),
            "flightNo": option.flightNumber?.isEmpty == false ? option.flightNumber! : option.id,
            // Dart `.round()`: half away from zero, to an int.
            "expectedPrice": Int((option.pricePerPax ?? option.price).rounded()),
            "fareBasis": option.fareBasis ?? option.fareBrand ?? "",
        ]
    }

    private static func pad(_ value: Int, _ width: Int) -> String {
        let digits = String(value)
        return String(repeating: "0", count: max(0, width - digits.count)) + digits
    }

    private static func dateOnly(_ date: DateTime) -> String {
        "\(pad(date.year, 4))-\(pad(date.month, 2))-\(pad(date.day, 2))"
    }

    /// Search results retain local wall-clock departure times. The booking API
    /// expects that Myanmar-local time with its explicit UTC offset.
    private static func myanmarDateTime(_ date: DateTime) -> String {
        "\(dateOnly(date))T\(pad(date.hour, 2)):\(pad(date.minute, 2)):\(pad(date.second, 2))+06:30"
    }
}

/// Reservation details returned by a successful `holdFlight` call.
struct FlightHoldResponse: Hashable {
    let ok: Bool
    let reason: String
    let message: String
    let bookingId: String
    let reference: String
    let pnr: String
    let pnrStatus: String?
    let ticketTimeLimit: String
    let ticketTimeLimitLocal: String
    let perPax: Double
    let total: Double
    let currency: String
    let passengers: Int
    let legs: [FlightHoldLeg]

    init(
        ok: Bool,
        reason: String,
        message: String,
        bookingId: String,
        reference: String,
        pnr: String,
        pnrStatus: String? = nil,
        ticketTimeLimit: String,
        ticketTimeLimitLocal: String,
        perPax: Double,
        total: Double,
        currency: String,
        passengers: Int,
        legs: [FlightHoldLeg]
    ) {
        self.ok = ok
        self.reason = reason
        self.message = message
        self.bookingId = bookingId
        self.reference = reference
        self.pnr = pnr
        self.pnrStatus = pnrStatus
        self.ticketTimeLimit = ticketTimeLimit
        self.ticketTimeLimitLocal = ticketTimeLimitLocal
        self.perPax = perPax
        self.total = total
        self.currency = currency
        self.passengers = passengers
        self.legs = legs
    }

    static func fromJson(_ json: JSON) -> FlightHoldResponse {
        FlightHoldResponse(
            ok: Dart.bool(json["ok"]) == true,
            reason: Dart.str(json["reason"]) ?? "",
            message: Dart.str(json["message"]) ?? "",
            bookingId: Dart.str(json["bookingId"]) ?? "",
            reference: Dart.str(json["reference"]) ?? "",
            pnr: Dart.str(json["pnr"]) ?? "",
            pnrStatus: Dart.str(json["pnrStatus"]),
            ticketTimeLimit: Dart.str(json["ticketTimeLimit"]) ?? "",
            ticketTimeLimitLocal: Dart.str(json["ticketTimeLimitLocal"]) ?? "",
            perPax: Dart.double(json["perPax"]) ?? 0,
            total: Dart.double(json["total"]) ?? 0,
            currency: Dart.str(json["currency"]) ?? "",
            passengers: Dart.int(json["passengers"]) ?? 0,
            legs: Dart.maps(json["legs"]).map { FlightHoldLeg.fromJson($0) }
        )
    }
}

/// A flight leg as confirmed by the airline. These values take precedence over
/// the original search result on the reservation-confirmation screen.
struct FlightHoldLeg: Hashable {
    let flightNo: String
    let from: String
    let to: String
    let date: String
    let departTime: String
    let arriveTime: String
    let price: Double
    let refundable: Bool
    let baggageKg: Int
    let fareBrand: String
    let rules: [String]

    init(
        flightNo: String,
        from: String,
        to: String,
        date: String,
        departTime: String,
        arriveTime: String,
        price: Double,
        refundable: Bool,
        baggageKg: Int,
        fareBrand: String,
        rules: [String]
    ) {
        self.flightNo = flightNo
        self.from = from
        self.to = to
        self.date = date
        self.departTime = departTime
        self.arriveTime = arriveTime
        self.price = price
        self.refundable = refundable
        self.baggageKg = baggageKg
        self.fareBrand = fareBrand
        self.rules = rules
    }

    static func fromJson(_ json: JSON) -> FlightHoldLeg {
        FlightHoldLeg(
            flightNo: Dart.str(json["flightNo"]) ?? "",
            from: Dart.str(json["from"]) ?? "",
            to: Dart.str(json["to"]) ?? "",
            date: Dart.str(json["date"]) ?? "",
            departTime: Dart.str(json["departTime"]) ?? "",
            arriveTime: Dart.str(json["arriveTime"]) ?? "",
            price: Dart.double(json["price"]) ?? 0,
            refundable: Dart.bool(json["refundable"]) == true,
            baggageKg: Dart.int(json["baggageKg"]) ?? 0,
            fareBrand: Dart.str(json["fareBrand"]) ?? "",
            rules: (Dart.list(json["rules"]) ?? []).map { Dart.interpolate($0) }
        )
    }
}
