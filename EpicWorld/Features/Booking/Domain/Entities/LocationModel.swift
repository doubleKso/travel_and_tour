// Port of lib/features/booking/domain/entities/location_model.dart

import Foundation

/// A selectable origin/destination for the From/To fields.
/// Works for both flights (airport) and buses (bus terminal / city).
struct LocationModel: Hashable {
    let code: String // e.g. "RGN", "CGK"
    let city: String // e.g. "Yangon"
    let facilityName: String // airport or terminal full name
    let country: String
    let searchCode: String
    let mode: TravelMode

    init(
        code: String,
        city: String,
        facilityName: String,
        country: String,
        searchCode: String = "",
        mode: TravelMode = .flight
    ) {
        self.code = code
        self.city = city
        self.facilityName = facilityName
        self.country = country
        self.searchCode = searchCode
        self.mode = mode
    }

    /// Text used when filtering the searchable list.
    var searchable: String {
        "\(code) \(searchCode) \(city) \(facilityName) \(country)".lowercased()
    }

    /// Route the search form opens on before the user picks anything. Living in
    /// the domain keeps the application layer free of any infrastructure import.
    static let defaultOrigin = LocationModel(
        code: "RGN",
        city: "Yangon",
        facilityName: "Yangon International Airport",
        country: "Myanmar"
    )

    static let defaultDestination = LocationModel(
        code: "MDL",
        city: "Mandalay",
        facilityName: "Mandalay International Airport",
        country: "Myanmar"
    )

    /// Dart's `json['code'] as String` / `json['city'] as String` casts throw
    /// on a missing or non-string value; this throws `FormatException` there.
    static func fromJson(_ json: JSON) throws -> LocationModel {
        guard let code = Dart.unwrap(json["code"]) as? String else {
            throw FormatException("LocationModel.code is not a String: \(Dart.interpolate(json["code"]))")
        }
        guard let city = Dart.unwrap(json["city"]) as? String else {
            throw FormatException("LocationModel.city is not a String: \(Dart.interpolate(json["city"]))")
        }
        let mode = Dart.unwrap(json["mode"]) as? String
        return LocationModel(
            code: code,
            city: city,
            facilityName: Dart.unwrap(json["facility_name"]) as? String ?? "",
            country: Dart.unwrap(json["country"]) as? String ?? "",
            searchCode: Dart.unwrap(json["searchCode"]) as? String
                ?? Dart.unwrap(json["search_code"]) as? String
                ?? "",
            mode: TravelMode.values.first { $0.name == mode } ?? .flight
        )
    }
}
