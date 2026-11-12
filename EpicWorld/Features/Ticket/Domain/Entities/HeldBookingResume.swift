// Port of lib/features/ticket/domain/entities/held_booking_resume.dart
import Foundation

/// Everything the payment screen needs to resume a held booking, rebuilt from
/// what `GetMyBookingByRef` and `GetMyBookingSegments` return.
///
/// The booking record carries the money and the contact; the segments carry
/// the itinerary. Neither alone is enough to redraw the payment screen, so the
/// two are combined here — away from the widget — and the result handed
/// straight to `FlightBookingBloc`'s `heldBookingResumed` event.
struct HeldBookingResume {
    let from: LocationModel
    let to: LocationModel
    let departDate: DateTime
    let adults: Int
    let children: Int
    let infants: Int
    let cabinClass: TravelClass
    let outbound: TripOptionModel
    let inbound: TripOptionModel?
    let holdRequest: FlightHoldRequest
    let holdResponse: FlightHoldResponse

    init(
        from: LocationModel,
        to: LocationModel,
        departDate: DateTime,
        adults: Int,
        children: Int,
        infants: Int,
        cabinClass: TravelClass,
        outbound: TripOptionModel,
        inbound: TripOptionModel?,
        holdRequest: FlightHoldRequest,
        holdResponse: FlightHoldResponse
    ) {
        self.from = from
        self.to = to
        self.departDate = departDate
        self.adults = adults
        self.children = children
        self.infants = infants
        self.cabinClass = cabinClass
        self.outbound = outbound
        self.inbound = inbound
        self.holdRequest = holdRequest
        self.holdResponse = holdResponse
    }

    static func from(
        _ booking: BookingHistoryItem,
        segments: [BookingHistorySegment] = []
    ) -> HeldBookingResume {
        let cabin = travelClassOf(booking.cabin)
        let codes = routeCodes(booking.route)

        // `direction` distinguishes the legs of a round trip; anything that is not
        // a return leg belongs to the outbound.
        let outSegments = segments.filter { !isReturnLeg($0.direction) }
        let inSegments = segments.filter { isReturnLeg($0.direction) }

        let fallbackDate = booking.createdAt?.toLocal() ?? DateTime.now()

        let outbound = leg(
            booking: booking,
            segment: outSegments.first,
            cabin: cabin,
            fallbackFrom: codes.from,
            fallbackTo: codes.to,
            fallbackDate: fallbackDate,
            suffix: "out"
        )
        let inbound: TripOptionModel? = inSegments.isEmpty
            ? nil
            : leg(
                booking: booking,
                segment: inSegments.first,
                cabin: cabin,
                fallbackFrom: codes.to,
                fallbackTo: codes.from,
                fallbackDate: fallbackDate,
                suffix: "in"
            )

        var selections: [JSON] = [FlightHoldRequest.selectionFrom(outbound)]
        if let inbound { selections.append(FlightHoldRequest.selectionFrom(inbound)) }

        return HeldBookingResume(
            from: location(outbound.originCode, outbound.originName),
            to: location(outbound.destinationCode, outbound.destinationName),
            departDate: outbound.departure,
            adults: booking.adults > 0 ? booking.adults : 1,
            children: booking.children,
            infants: booking.infants,
            cabinClass: cabin,
            outbound: outbound,
            inbound: inbound,
            holdRequest: FlightHoldRequest(
                selections: selections,
                // Passenger rows are not needed to confirm an existing reservation —
                // `confirmTicketing` keys off the reference and the contact email.
                passengers: [],
                contact: [
                    "title": booking.contactTitle,
                    "fullName": booking.contactFullName,
                    "email": booking.contactEmail,
                    "phone": booking.contactPhone,
                    "countryCode": booking.contactCountryCode,
                ]
            ),
            holdResponse: FlightHoldResponse(
                ok: true,
                reason: "",
                message: "",
                bookingId: booking.id,
                reference: booking.reference,
                pnr: booking.pnr,
                ticketTimeLimit: booking.ticketTimeLimit?.toIso8601String() ?? "",
                ticketTimeLimitLocal: "",
                perPax: booking.perPaxFare,
                total: booking.total,
                currency: booking.currency,
                passengers: booking.adults + booking.children + booking.infants,
                legs: []
            )
        )
    }

    /// `economy` / `business` as the server spells it.
    static func travelClassOf(_ cabin: String) -> TravelClass {
        cabin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "BUSINESS"
            ? .business
            : .economy
    }

    /// Pulls the two airport codes out of a `RGN -> SIN` route string. Falls back
    /// to empty codes when the route is missing or unrecognised.
    static func routeCodes(_ route: String) -> (from: String, to: String) {
        // Dart: route.split(RegExp('[→><–-]+')).
        let separator = "\u{0}"
        let parts = route
            .replacingOccurrences(of: "[→><–-]+", with: separator, options: .regularExpression)
            .components(separatedBy: separator)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if parts.count < 2 { return (from: "", to: "") }
        return (from: parts[0], to: parts[1])
    }

    /// Combines a segment's `2026-09-02` date with its `07:25 AM` time.
    static func dateTimeOf(_ date: String, _ time: String, _ fallback: DateTime) -> DateTime {
        guard let day = DateTime.tryParse(date.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return fallback
        }
        let text = time.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let regex = try? NSRegularExpression(pattern: #"^(\d{1,2}):(\d{2})\s*([AaPp][Mm])?$"#),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return DateTime(day.year, day.month, day.day)
        }
        func group(_ index: Int) -> String? {
            guard let range = Range(match.range(at: index), in: text) else { return nil }
            return String(text[range])
        }
        var hour = Int(group(1) ?? "") ?? 0
        let minute = Int(group(2) ?? "") ?? 0
        let meridiem = group(3)?.uppercased()
        if meridiem == "PM" && hour != 12 { hour += 12 }
        if meridiem == "AM" && hour == 12 { hour = 0 }
        return DateTime(day.year, day.month, day.day, hour, minute)
    }

    static func isReturnLeg(_ direction: String) -> Bool {
        let value = direction.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value == "return" || value == "inbound" || value == "in"
    }

    private static func location(_ code: String, _ city: String) -> LocationModel {
        LocationModel(
            code: code,
            city: city.isEmpty ? code : city,
            facilityName: city.isEmpty ? code : city,
            country: ""
        )
    }

    private static func leg(
        booking: BookingHistoryItem,
        segment: BookingHistorySegment?,
        cabin: TravelClass,
        fallbackFrom: String,
        fallbackTo: String,
        fallbackDate: DateTime,
        suffix: String
    ) -> TripOptionModel {
        let departure = segment.map { dateTimeOf($0.travelDate, $0.departTime, fallbackDate) } ?? fallbackDate
        let arrival = segment.map { dateTimeOf($0.travelDate, $0.arriveTime, departure) } ?? departure
        let segmentPrice = segment?.price ?? 0
        return TripOptionModel(
            id: "\(booking.reference)-\(suffix)",
            mode: .flight,
            operatorName: segment?.carrierName ?? "",
            operatorLogoUrl: "",
            originCode: (segment.map { !$0.fromCode.isEmpty } ?? false) ? segment!.fromCode : fallbackFrom,
            originName: segment?.fromCity ?? "",
            destinationCode: (segment.map { !$0.toCode.isEmpty } ?? false) ? segment!.toCode : fallbackTo,
            destinationName: segment?.toCity ?? "",
            departure: departure,
            // An arrival parsed as earlier than departure means the leg lands on the
            // following day.
            arrival: arrival.isBefore(departure) ? arrival.add(Duration(days: 1)) : arrival,
            stops: segment?.stops ?? 0,
            travelClass: cabin,
            price: segmentPrice > 0 ? segmentPrice : booking.perPaxFare,
            currency: booking.currency,
            flightNumber: segment?.flightNo,
            bookable: true,
            baggageKg: segment?.baggageKg,
            fareBrand: segment?.fareBrand,
            refundable: segment?.refundable
        )
    }
}
