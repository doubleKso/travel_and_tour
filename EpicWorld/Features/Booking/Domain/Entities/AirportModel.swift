// Port of lib/features/booking/domain/entities/airport_model.dart

import Foundation

/// An airport/place returned by the public active-airports catalogue.
struct AirportModel: Hashable {
    let id: String
    let code: String
    let name: String
    let cityName: String
    let country: String
    let searchCode: String
    let active: Bool
    let createdAt: String
    let updatedAt: String

    init(
        id: String,
        code: String,
        name: String,
        cityName: String,
        country: String,
        searchCode: String,
        active: Bool,
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.cityName = cityName
        self.country = country
        self.searchCode = searchCode
        self.active = active
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func fromJson(_ json: JSON) -> AirportModel {
        AirportModel(
            // `ListActiveAirports` only returns active places, so the legacy fields
            // retain sensible values for existing picker consumers.
            id: Dart.str(json["id"]) ?? Dart.str(json["code"]) ?? "",
            code: Dart.str(json["code"]) ?? "",
            name: Dart.str(json["name"]) ?? "",
            cityName: Dart.str(json["city"]) ?? Dart.str(json["cityName"]) ?? "",
            country: Dart.str(json["country"]) ?? "",
            searchCode: Dart.str(json["searchCode"]) ?? "",
            // Dart `json['active'] != false`: anything but a literal `false` is active.
            active: Dart.bool(json["active"]) != false,
            createdAt: Dart.str(json["createdAt"]) ?? "",
            updatedAt: Dart.str(json["updatedAt"]) ?? ""
        )
    }
}
