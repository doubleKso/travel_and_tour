// Port of lib/features/booking/domain/entities/airport_country_model.dart

import Foundation

/// A country currently available in the flight catalogue.
struct AirportCountryModel: Hashable {
    let code: String
    let name: String
    let logoUrl: String

    init(code: String, name: String, logoUrl: String) {
        self.code = code
        self.name = name
        self.logoUrl = logoUrl
    }

    static func fromJson(_ json: JSON) -> AirportCountryModel {
        AirportCountryModel(
            code: Dart.str(json["code"]) ?? "",
            name: Dart.str(json["name"]) ?? "",
            logoUrl: Dart.str(json["logoUrl"]) ?? ""
        )
    }
}
