// Port of lib/features/booking/domain/entities/flight_search_request.dart

import Foundation

/// Request payload for the Firebase `searchFlights` callable.
struct FlightSearchRequest: Hashable {
    let from: String
    let to: String
    let departDate: String

    /// Return date of a round trip. Null for a one-way search, and left out of
    /// the payload altogether.
    let returnDate: String?
    let adults: Int
    let children: Int
    let infants: Int

    /// Cabin to search — `Economy` or `Business`. The service filters on this, so
    /// it decides which fares come back at all; the class filter on the results
    /// list can only narrow what this asked for.
    let cabin: String

    /// Nationality chosen on the search form, as a code — `MM` for Myanmar.
    let nationality: String

    init(
        from: String,
        to: String,
        departDate: String,
        returnDate: String? = nil,
        adults: Int,
        children: Int,
        infants: Int,
        cabin: String,
        nationality: String
    ) {
        self.from = from
        self.to = to
        self.departDate = departDate
        self.returnDate = returnDate
        self.adults = adults
        self.children = children
        self.infants = infants
        self.cabin = cabin
        self.nationality = nationality
    }

    /// The callable's `data` object. The Firebase SDK adds the `{"data": ...}`
    /// envelope when it sends the request, so it must not be added here.
    func toJson() -> JSON {
        var json: JSON = [
            "from": from,
            "to": to,
            "departDate": departDate,
        ]
        if let returnDate { json["returnDate"] = returnDate }
        json["adults"] = adults
        json["children"] = children
        json["infants"] = infants
        json["cabin"] = cabin
        json["nationality"] = nationality
        return json
    }
}
