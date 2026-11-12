// Port of lib/features/booking/domain/entities/flight_schedule_model.dart

import Foundation

/// A public, read-only commercial flight schedule.
struct FlightScheduleModel: Hashable {
    let airlineCode: String
    let airlineName: String
    let logoUrl: String
    let flightNo: String
    let fromCode: String
    let fromCity: String
    let toCode: String
    let toCity: String
    let departTime: String
    let arriveTime: String
    let arrivesNextDay: Bool
    let daysOfWeek: String
    let stops: Int
    let indicativeFare: Double
    let currency: String
    let effectiveFrom: String
    let effectiveTo: String

    init(
        airlineCode: String,
        airlineName: String,
        logoUrl: String = "",
        flightNo: String,
        fromCode: String,
        fromCity: String,
        toCode: String,
        toCity: String,
        departTime: String,
        arriveTime: String,
        arrivesNextDay: Bool,
        daysOfWeek: String,
        stops: Int,
        indicativeFare: Double,
        currency: String,
        effectiveFrom: String,
        effectiveTo: String
    ) {
        self.airlineCode = airlineCode
        self.airlineName = airlineName
        self.logoUrl = logoUrl
        self.flightNo = flightNo
        self.fromCode = fromCode
        self.fromCity = fromCity
        self.toCode = toCode
        self.toCity = toCity
        self.departTime = departTime
        self.arriveTime = arriveTime
        self.arrivesNextDay = arrivesNextDay
        self.daysOfWeek = daysOfWeek
        self.stops = stops
        self.indicativeFare = indicativeFare
        self.currency = currency
        self.effectiveFrom = effectiveFrom
        self.effectiveTo = effectiveTo
    }

    /// Airline heading shown in the commercial schedule. A flight number is
    /// optional catalogue data and must never be synthesized by the client.
    var airlineAndFlightLabel: String {
        let airline = airlineName.trimmingCharacters(in: .whitespacesAndNewlines)
        let number = flightNo.trimmingCharacters(in: .whitespacesAndNewlines)
        if number.isEmpty { return airline }
        if airline.isEmpty { return number }
        return "\(airline), \(number)"
    }

    static func fromJson(_ json: JSON) -> FlightScheduleModel {
        FlightScheduleModel(
            airlineCode: Dart.str(json["airlineCode"]) ?? "",
            airlineName: Dart.str(json["airlineName"]) ?? "",
            logoUrl: Dart.str(json["logoUrl"]) ?? Dart.str(json["airlineLogo"]) ?? "",
            flightNo: Dart.str(json["flightNo"]) ?? "",
            fromCode: Dart.str(json["fromCode"]) ?? "",
            fromCity: Dart.str(json["fromCity"]) ?? "",
            toCode: Dart.str(json["toCode"]) ?? "",
            toCity: Dart.str(json["toCity"]) ?? "",
            departTime: Dart.str(json["departTime"]) ?? "",
            arriveTime: Dart.str(json["arriveTime"]) ?? "",
            arrivesNextDay: Dart.bool(json["arrivesNextDay"]) == true,
            daysOfWeek: Dart.str(json["daysOfWeek"]) ?? "",
            stops: Dart.isNum(json["stops"])
                ? (Dart.int(json["stops"]) ?? 0)
                : Dart.parseInt(Dart.str(json["stops"]) ?? "") ?? 0,
            indicativeFare: Dart.double(json["indicativeFare"]) ?? 0,
            currency: Dart.str(json["currency"]) ?? "",
            effectiveFrom: Dart.str(json["effectiveFrom"]) ?? "",
            effectiveTo: Dart.str(json["effectiveTo"]) ?? ""
        )
    }

    /// Whether this schedule can be shown for the route and calendar day that
    /// the customer searched. `daily` and common weekday list formats are both
    /// supported by the catalogue.
    func operatesOn(from: String, to: String, date: DateTime) -> Bool {
        if fromCode.uppercased() != from.uppercased() || toCode.uppercased() != to.uppercased() {
            return false
        }
        let day = DateTime(date.year, date.month, date.day)
        let fromDate = Self.date(effectiveFrom)
        let toDate = Self.date(effectiveTo)
        if let fromDate, day.isBefore(fromDate) { return false }
        if let toDate, day.isAfter(toDate) { return false }

        let scheduleDays = daysOfWeek.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if scheduleDays.isEmpty || scheduleDays == "daily" { return true }
        let shortDays = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
        let fullDays = [
            "monday",
            "tuesday",
            "wednesday",
            "thursday",
            "friday",
            "saturday",
            "sunday",
        ]
        let index = day.weekday - 1
        return scheduleDays.range(
            of: "\\b(\(shortDays[index])|\(fullDays[index]))\\b",
            options: .regularExpression
        ) != nil
    }

    /// The nearest scheduled date used to pre-fill an enquiry from the public
    /// timetable. The customer can still select another preferred date in the
    /// enquiry form.
    func nextOperatingDate(_ from: DateTime? = nil) -> DateTime {
        let start = from ?? DateTime.now()
        let firstDay = DateTime(start.year, start.month, start.day)
        for offset in 0..<366 {
            let candidate = firstDay.add(Duration(days: offset))
            if operatesOn(from: fromCode, to: toCode, date: candidate) {
                return candidate
            }
        }
        return firstDay
    }

    /// Converts a catalogue schedule to an enquiry-only search result.
    func toTripOption(
        _ date: DateTime,
        carrierLogoUrl: String? = nil,
        carrierName: String? = nil
    ) -> TripOptionModel {
        let departure = Self.dateTime(date, departTime)
        var arrival = Self.dateTime(date, arriveTime)
        if arrivesNextDay || !arrival.isAfter(departure) {
            arrival = arrival.add(Duration(days: 1))
        }
        let dateKey = "\(Self.pad(date.year, 4))-\(Self.pad(date.month, 2))-\(Self.pad(date.day, 2))"
        let trimmedCarrierName = carrierName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCarrierLogo = carrierLogoUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFlightNo = flightNo.trimmingCharacters(in: .whitespacesAndNewlines)
        return TripOptionModel(
            id: "schedule-\(airlineCode)-\(flightNo)-\(fromCode)-\(toCode)-\(dateKey)-\(departTime)",
            mode: .flight,
            operatorName: trimmedCarrierName?.isEmpty == false ? trimmedCarrierName! : airlineName,
            operatorLogoUrl: trimmedCarrierLogo?.isEmpty == false
                ? trimmedCarrierLogo!
                : logoUrl.trimmingCharacters(in: .whitespacesAndNewlines),
            carrierCode: airlineCode,
            originCode: fromCode,
            originName: fromCity,
            destinationCode: toCode,
            destinationName: toCity,
            departure: departure,
            arrival: arrival,
            stops: stops,
            travelClass: .economy,
            price: indicativeFare,
            currency: currency.isEmpty ? "MMK" : currency,
            flightNumber: trimmedFlightNo.isEmpty ? nil : trimmedFlightNo,
            bookable: false
        )
    }

    private static func date(_ value: String) -> DateTime? {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
        return DateTime.tryParse(value)
    }

    private static let timePattern = try! NSRegularExpression(
        pattern: #"^(\d{1,2}):(\d{2})\s*(AM|PM)?$"#,
        options: [.caseInsensitive]
    )

    private static func dateTime(_ date: DateTime, _ time: String) -> DateTime {
        let text = time.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let match = timePattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return DateTime(date.year, date.month, date.day)
        }
        func group(_ index: Int) -> String? {
            guard let range = Range(match.range(at: index), in: text) else { return nil }
            return String(text[range])
        }
        var hour = Int(group(1) ?? "") ?? 0
        let period = group(3)?.uppercased()
        if period == "PM" && hour != 12 { hour += 12 }
        if period == "AM" && hour == 12 { hour = 0 }
        return DateTime(
            date.year,
            date.month,
            date.day,
            hour,
            Int(group(2) ?? "") ?? 0
        )
    }

    private static func pad(_ value: Int, _ width: Int) -> String {
        let digits = String(value)
        return String(repeating: "0", count: max(0, width - digits.count)) + digits
    }
}
