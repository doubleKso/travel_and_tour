// Port of lib/features/booking/domain/entities/flight_search_response.dart

import Foundation

/// Typed result returned by the Firebase `searchFlights` callable.
///
/// Firebase normally unwraps callable results, while some clients expose the
/// outer `result` object. `fromJson` accepts both shapes.
struct FlightSearchResponse {
    let options: [TripOptionModel]
    let live: Bool
    let notice: String?

    init(options: [TripOptionModel], live: Bool, notice: String? = nil) {
        self.options = options
        self.live = live
        self.notice = notice
    }

    static func fromJson(_ json: JSON) -> FlightSearchResponse {
        let payload = asMap(json["result"]) ?? json
        // The callable may return MAI results as `options` and enquiry-only
        // airlines in a companion list. Accept the deployed and legacy names so
        // all airlines make it into the same search-results list.
        let optionKeys = [
            "options",
            "otherAirlines",
            "otherAirlineOptions",
            "nonMaiOptions",
            "enquiryOptions",
            "inquiryOptions",
            "airlineOptions",
            "flights",
        ]
        var seenIds = Set<String>()
        var options: [TripOptionModel] = []
        for key in optionKeys {
            let rawOptions = payload[key]
            guard Dart.isList(rawOptions) else { continue }
            for item in Dart.maps(rawOptions) {
                let option = optionFromJson(item)
                // Some integrations publish the same MAI option in two collections.
                if !option.id.isEmpty && !seenIds.insert(option.id).inserted { continue }
                options.append(option)
            }
        }

        return FlightSearchResponse(
            options: options,
            live: Dart.bool(payload["live"]) ?? false,
            notice: Dart.str(payload["notice"])
        )
    }

    private static func optionFromJson(_ json: JSON) -> TripOptionModel {
        let carrier = asMap(json["carrier"]) ?? [:]
        let from = asMap(json["from"]) ?? asMap(json["origin"]) ?? [:]
        let to = asMap(json["to"]) ?? asMap(json["destination"]) ?? [:]
        let segments = json["segments"]
        let segmentList = Dart.list(segments)
        let firstSegment: JSON? = segmentList.flatMap { $0.isEmpty ? nil : asMap($0.first) }

        return TripOptionModel(
            id: Dart.str(json["id"]) ?? "",
            mode: travelMode(Dart.str(json["mode"])),
            operatorName: firstNonEmpty([
                carrier["name"],
                json["airlineName"],
                json["operatorName"],
            ]) ?? "",
            operatorLogoUrl: logoUrl(
                firstNonEmpty([
                    carrier["logo"],
                    carrier["logoUrl"],
                    json["airlineLogo"],
                    json["logoUrl"],
                ])
            ),
            carrierCode: firstNonEmpty([
                carrier["code"],
                json["carrierCode"],
                json["airlineCode"],
                carrier["id"],
            ]),
            originCode: Dart.str(from["code"]) ?? Dart.str(json["fromCode"]) ?? "",
            originName: placeName(from, fallback: Dart.str(json["fromName"])),
            destinationCode: Dart.str(to["code"]) ?? Dart.str(json["toCode"]) ?? "",
            destinationName: placeName(to, fallback: Dart.str(json["toName"])),
            departure: wallClockTime(
                Dart.str(firstSegment?["departAt"]),
                Dart.str(json["date"]),
                Dart.str(json["departTime"])
            ),
            arrival: wallClockTime(
                Dart.str(firstSegment?["arriveAt"]),
                Dart.str(json["date"]),
                Dart.str(json["arriveTime"]),
                dayOffset: Dart.int(json["arriveDayOffset"]) ?? 0
            ),
            stops: stops(json["stops"], segments),
            travelClass: travelClass(Dart.str(json["cabin"])),
            price: number(firstNonNull(json["totalPrice"], json["price"], json["indicativeFare"])),
            pricePerPax: Dart.isNull(json["price"]) ? nil : number(json["price"]),
            currency: Dart.str(json["currency"]) ?? "MMK",
            flightNumber: firstNonEmpty([
                json["flightNo"],
                firstSegment?["flightNumber"],
            ]),
            bookingClass: Dart.str(json["bookingClass"]) ?? Dart.str(firstSegment?["bookingClass"]),
            aircraft: Dart.str(json["aircraft"]) ?? Dart.str(firstSegment?["aircraft"]),
            departureTerminal: Dart.str(json["departTerminal"]),
            arrivalTerminal: Dart.str(json["arriveTerminal"]),
            amenities: (Dart.list(json["amenities"]) ?? []).map { Dart.interpolate($0) },
            bookable: Dart.bool(json["bookable"]),
            baggageKg: Dart.int(json["baggageKg"]) ?? selectedBaggageKg(json["fares"]),
            seatsLeft: Dart.int(json["seatsLeft"]),
            fareBrand: Dart.str(json["fareBrand"]),
            fareBasis: Dart.str(json["fareBasis"])
                ?? Dart.str(json["fare_basis"])
                ?? selectedFareBasis(json["fares"]),
            refundable: Dart.bool(json["refundable"]),
            fareOptions: faresFromJson(
                json["fares"],
                fallbackClass: travelClass(Dart.str(json["cabin"])),
                fallbackCurrency: Dart.str(json["currency"]) ?? "MMK"
            )
        )
    }

    private static func asMap(_ value: Any?) -> JSON? {
        Dart.map(value)
    }

    /// Dart `a ?? b ?? c` over dynamic JSON values (JSON null counts as null).
    private static func firstNonNull(_ values: Any?...) -> Any? {
        for value in values where !Dart.isNull(value) { return Dart.unwrap(value) }
        return nil
    }

    private static func number(_ value: Any?) -> Double {
        Dart.isNum(value)
            ? (Dart.double(value) ?? 0)
            : Dart.parseDouble(Dart.str(value) ?? "") ?? 0
    }

    private static func firstNonEmpty(_ values: [Any?]) -> String? {
        for value in values {
            let text = Dart.str(value)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !text.isEmpty { return text }
        }
        return nil
    }

    private static func stops(_ value: Any?, _ segments: Any?) -> Int {
        if Dart.isNum(value) {
            let stops = Dart.int(value) ?? 0
            return stops < 0 ? 0 : stops
        }
        let text = Dart.str(value)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let numeric = Dart.parseInt(text) { return numeric < 0 ? 0 : numeric }
        let normalized = text.lowercased().replacingOccurrences(of: "[^a-z]", with: "", options: .regularExpression)
        if normalized == "nonstop" || normalized == "direct" { return 0 }
        if let range = text.range(of: #"\d+"#, options: .regularExpression), let embedded = Int(text[range]) {
            return embedded
        }
        if let list = Dart.list(segments), !list.isEmpty { return list.count - 1 }
        return 0
    }

    private static let markdownLinkPattern = try! NSRegularExpression(pattern: #"^\[[^\]]*\]\(([^)]+)\)$"#)

    /// Clipboard/Markdown previews can wrap a URL as `[url](url)`. Production
    /// calls return the plain URL, but accepting both keeps logo rendering safe.
    private static func logoUrl(_ value: Any?) -> String {
        let raw = Dart.str(value) ?? ""
        guard let match = markdownLinkPattern.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)),
              let range = Range(match.range(at: 1), in: raw) else { return raw }
        return String(raw[range])
    }

    private static func faresFromJson(
        _ raw: Any?,
        fallbackClass: TravelClass,
        fallbackCurrency: String
    ) -> [FareOptionModel] {
        guard Dart.isList(raw) else { return [] }
        return Dart.maps(raw).map { fare in
            let basis = Dart.str(fare["fareBasis"]) ?? Dart.str(fare["fare_basis"])
            let brand = Dart.str(fare["fareBrand"])
                ?? Dart.str(fare["brand"])
                ?? Dart.str(fare["name"])
                ?? basis
                ?? "Economy"
            return FareOptionModel(
                id: Dart.str(fare["id"]) ?? basis ?? brand,
                brand: brand,
                basis: basis,
                bookingClass: Dart.str(fare["bookingClass"]),
                travelClass: !Dart.isNull(fare["cabin"]) || !Dart.isNull(fare["travelClass"])
                    ? travelClass(Dart.str(fare["cabin"]) ?? Dart.str(fare["travelClass"]))
                    : fallbackClass,
                price: number(firstNonNull(fare["totalPrice"], fare["price"], fare["amount"])),
                pricePerPax: Dart.isNull(fare["price"]) ? nil : number(fare["price"]),
                currency: Dart.str(fare["currency"]) ?? fallbackCurrency,
                baggageKg: Dart.int(fare["baggageKg"]),
                refundable: Dart.bool(fare["refundable"]) == true,
                selected: Dart.bool(fare["selected"]) == true
            )
        }
    }

    private static func placeName(_ place: JSON, fallback: String? = nil) -> String {
        Dart.str(place["city"]) ?? Dart.str(place["name"]) ?? fallback ?? ""
    }

    private static func travelMode(_ value: String?) -> TravelMode {
        value?.lowercased() == TravelMode.bus.name ? .bus : .flight
    }

    private static func travelClass(_ value: String?) -> TravelClass {
        switch value?.uppercased() {
        // 'PREMIUM_ECONOMY' || 'PREMIUM ECONOMY' => TravelClass.premiumEconomy,
        case "BUSINESS": return .business
        // 'FIRST' || 'FIRST_CLASS' => TravelClass.first,
        default: return .economy
        }
    }

    private static func selectedBaggageKg(_ rawFares: Any?) -> Int? {
        guard Dart.isList(rawFares) else { return nil }
        for fare in Dart.maps(rawFares) where Dart.bool(fare["selected"]) == true {
            return Dart.int(fare["baggageKg"])
        }
        return nil
    }

    private static func selectedFareBasis(_ rawFares: Any?) -> String? {
        guard Dart.isList(rawFares) else { return nil }
        for fare in Dart.maps(rawFares) where Dart.bool(fare["selected"]) == true {
            return Dart.str(fare["fareBasis"]) ?? Dart.str(fare["fare_basis"])
        }
        return nil
    }

    private static let isoPattern = try! NSRegularExpression(pattern: #"^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})"#)
    private static let datePattern = try! NSRegularExpression(pattern: #"^(\d{4})-(\d{2})-(\d{2})"#)
    private static let timePattern = try! NSRegularExpression(
        pattern: #"^(\d{1,2}):(\d{2})\s*(AM|PM)?$"#,
        options: [.caseInsensitive]
    )

    /// The capture groups of `pattern`'s first match in `text` (nil groups for
    /// optional parts that did not take part), or nil when nothing matches.
    private static func groups(_ pattern: NSRegularExpression, _ text: String) -> [String?]? {
        guard let match = pattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        return (0..<match.numberOfRanges).map { index in
            Range(match.range(at: index), in: text).map { String(text[$0]) }
        }
    }

    /// Produces the advertised local clock time rather than converting it to the
    /// phone's timezone. The API supplies an ISO timestamp for each segment.
    private static func wallClockTime(
        _ iso: String?,
        _ date: String?,
        _ time: String?,
        dayOffset: Int = 0
    ) -> DateTime {
        let isoMatch = iso.flatMap { groups(isoPattern, $0) }
        if let isoMatch {
            return DateTime(
                Int(isoMatch[1] ?? "") ?? 0,
                Int(isoMatch[2] ?? "") ?? 0,
                Int(isoMatch[3] ?? "") ?? 0,
                Int(isoMatch[4] ?? "") ?? 0,
                Int(isoMatch[5] ?? "") ?? 0
            )
        }

        let dateMatch = date.flatMap { groups(datePattern, $0) }
        let timeMatch = time.flatMap { groups(timePattern, $0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        if let dateMatch, let timeMatch {
            var hour = Int(timeMatch[1] ?? "") ?? 0
            let period = timeMatch[3]?.uppercased()
            if period == "PM" && hour != 12 { hour += 12 }
            if period == "AM" && hour == 12 { hour = 0 }
            return DateTime(
                Int(dateMatch[1] ?? "") ?? 0,
                Int(dateMatch[2] ?? "") ?? 0,
                (Int(dateMatch[3] ?? "") ?? 0) + dayOffset,
                hour,
                Int(timeMatch[2] ?? "") ?? 0
            )
        }
        return DateTime.fromMillisecondsSinceEpoch(0)
    }
}
