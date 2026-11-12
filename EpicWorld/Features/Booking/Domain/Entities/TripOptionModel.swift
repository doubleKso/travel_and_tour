// Port of lib/features/booking/domain/entities/trip_option_model.dart

import Foundation

/// A single bookable option in the search results list — one flight leg or one
/// bus departure. Kept generic so the same result list / card works for both
/// travel modes.
struct TripOptionModel: Hashable {
    let id: String
    let mode: TravelMode
    let operatorName: String // airline or bus company
    let operatorLogoUrl: String

    /// IATA carrier code returned by flight search, e.g. `8M` for MAI.
    /// Kept separately from `flightNumber` so booking eligibility does not
    /// depend on how an airline formats its display name.
    let carrierCode: String?

    let originCode: String // e.g. "RGN" or city code
    let originName: String
    let destinationCode: String
    let destinationName: String

    let departure: DateTime
    let arrival: DateTime
    let stops: Int // 0 = direct/non-stop
    let travelClass: TravelClass

    /// Total for every passenger in the search.
    let price: Double

    /// `price` spread over the passengers, as the search service quotes it.
    /// `holdFlight` checks its `expectedPrice` against this figure, so sending
    /// the total would be read as a fare change whenever more than one person
    /// travels. Null for sources that only give a single figure.
    let pricePerPax: Double?
    let currency: String

    /// Extra live-search data used by the result details sheet. Mock options can
    /// omit these safely.
    let flightNumber: String?
    let bookingClass: String?
    let aircraft: String?
    let departureTerminal: String?
    let arrivalTerminal: String?
    let amenities: [String]

    /// Explicit booking capability returned by the live search service.
    let bookable: Bool?
    let baggageKg: Int?
    let seatsLeft: Int?
    let fareBrand: String?

    /// Airline fare code required by `holdFlight`; this is distinct from the
    /// human-readable `fareBrand` label shown in the results UI.
    let fareBasis: String?
    let refundable: Bool?

    /// All purchasable fares for this same itinerary. Non-MAI airlines normally
    /// omit this list because they are handled through an enquiry instead.
    let fareOptions: [FareOptionModel]

    init(
        id: String,
        mode: TravelMode,
        operatorName: String,
        operatorLogoUrl: String,
        carrierCode: String? = nil,
        originCode: String,
        originName: String,
        destinationCode: String,
        destinationName: String,
        departure: DateTime,
        arrival: DateTime,
        stops: Int,
        travelClass: TravelClass,
        price: Double,
        pricePerPax: Double? = nil,
        currency: String,
        flightNumber: String? = nil,
        bookingClass: String? = nil,
        aircraft: String? = nil,
        departureTerminal: String? = nil,
        arrivalTerminal: String? = nil,
        amenities: [String] = [],
        bookable: Bool? = nil,
        baggageKg: Int? = nil,
        seatsLeft: Int? = nil,
        fareBrand: String? = nil,
        fareBasis: String? = nil,
        refundable: Bool? = nil,
        fareOptions: [FareOptionModel] = []
    ) {
        self.id = id
        self.mode = mode
        self.operatorName = operatorName
        self.operatorLogoUrl = operatorLogoUrl
        self.carrierCode = carrierCode
        self.originCode = originCode
        self.originName = originName
        self.destinationCode = destinationCode
        self.destinationName = destinationName
        self.departure = departure
        self.arrival = arrival
        self.stops = stops
        self.travelClass = travelClass
        self.price = price
        self.pricePerPax = pricePerPax
        self.currency = currency
        self.flightNumber = flightNumber
        self.bookingClass = bookingClass
        self.aircraft = aircraft
        self.departureTerminal = departureTerminal
        self.arrivalTerminal = arrivalTerminal
        self.amenities = amenities
        self.bookable = bookable
        self.baggageKg = baggageKg
        self.seatsLeft = seatsLeft
        self.fareBrand = fareBrand
        self.fareBasis = fareBasis
        self.refundable = refundable
        self.fareOptions = fareOptions
    }

    var duration: Duration { arrival.difference(departure) }

    var isDirect: Bool { stops == 0 }

    /// Returns the same itinerary with `fare` promoted to the selected fare.
    /// This is the instance stored in booking state and later submitted to the
    /// airline, so its price and fare basis must match what the user chose.
    func withFare(_ fare: FareOptionModel) -> TripOptionModel {
        TripOptionModel(
            id: id,
            mode: mode,
            operatorName: operatorName,
            operatorLogoUrl: operatorLogoUrl,
            carrierCode: carrierCode,
            originCode: originCode,
            originName: originName,
            destinationCode: destinationCode,
            destinationName: destinationName,
            departure: departure,
            arrival: arrival,
            stops: stops,
            travelClass: fare.travelClass,
            price: fare.price,
            pricePerPax: fare.pricePerPax,
            currency: fare.currency,
            flightNumber: flightNumber,
            bookingClass: fare.bookingClass ?? bookingClass,
            aircraft: aircraft,
            departureTerminal: departureTerminal,
            arrivalTerminal: arrivalTerminal,
            amenities: amenities,
            bookable: bookable,
            baggageKg: fare.baggageKg ?? baggageKg,
            seatsLeft: seatsLeft,
            fareBrand: fare.brand,
            fareBasis: fare.basis ?? fareBrand,
            refundable: fare.refundable,
            fareOptions: fareOptions
        )
    }

    /// Dart's hard casts (`json['id'] as String`, `DateTime.parse(json['departure'] as String)`,
    /// `(json['price'] as num)`) throw on a missing value; this throws there too.
    static func fromJson(_ json: JSON) throws -> TripOptionModel {
        guard let id = Dart.unwrap(json["id"]) as? String else {
            throw FormatException("TripOptionModel.id is not a String: \(Dart.interpolate(json["id"]))")
        }
        guard let departureText = Dart.unwrap(json["departure"]) as? String else {
            throw FormatException("TripOptionModel.departure is not a String: \(Dart.interpolate(json["departure"]))")
        }
        guard let arrivalText = Dart.unwrap(json["arrival"]) as? String else {
            throw FormatException("TripOptionModel.arrival is not a String: \(Dart.interpolate(json["arrival"]))")
        }
        guard let price = Dart.double(json["price"]) else {
            throw FormatException("TripOptionModel.price is not a num: \(Dart.interpolate(json["price"]))")
        }
        let mode = Dart.unwrap(json["mode"]) as? String
        let travelClass = Dart.unwrap(json["travel_class"]) as? String
        return TripOptionModel(
            id: id,
            mode: TravelMode.values.first { $0.name == mode } ?? .flight,
            operatorName: Dart.unwrap(json["operator_name"]) as? String ?? "",
            operatorLogoUrl: Dart.unwrap(json["operator_logo_url"]) as? String ?? "",
            carrierCode: Dart.unwrap(json["carrier_code"]) as? String,
            originCode: Dart.unwrap(json["origin_code"]) as? String ?? "",
            originName: Dart.unwrap(json["origin_name"]) as? String ?? "",
            destinationCode: Dart.unwrap(json["destination_code"]) as? String ?? "",
            destinationName: Dart.unwrap(json["destination_name"]) as? String ?? "",
            departure: try DateTime.parse(departureText),
            arrival: try DateTime.parse(arrivalText),
            stops: Dart.int(json["stops"]) ?? 0,
            travelClass: TravelClass.values.first { $0.name == travelClass } ?? .economy,
            price: price,
            currency: Dart.unwrap(json["currency"]) as? String ?? "MMK"
        )
    }
}
