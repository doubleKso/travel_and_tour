// Port of lib/features/booking/domain/entities/airport_city_model.dart

import Foundation

/// A city that has one or more active airports in the flight catalogue.
struct AirportCityModel: Hashable {
    let code: String
    let name: String
    let country: String
    let isDomestic: Bool
    let isInternational: Bool

    init(code: String, name: String, country: String, isDomestic: Bool, isInternational: Bool) {
        self.code = code
        self.name = name
        self.country = country
        self.isDomestic = isDomestic
        self.isInternational = isInternational
    }

    static func fromJson(_ json: JSON) -> AirportCityModel {
        AirportCityModel(
            code: Dart.str(json["code"]) ?? "",
            name: Dart.str(json["name"]) ?? "",
            country: Dart.str(json["country"]) ?? "",
            isDomestic: Dart.bool(json["isDomestic"]) == true,
            isInternational: Dart.bool(json["isInternational"]) == true
        )
    }

    /// `ListActiveAirportCities` can return both scopes in one response, so the
    /// client also filters on the availability flags supplied by the API.
    func isAvailableFor(domestic: Bool) -> Bool {
        domestic ? isDomestic : isInternational
    }
}
