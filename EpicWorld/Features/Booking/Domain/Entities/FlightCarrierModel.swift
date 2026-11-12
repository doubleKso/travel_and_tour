// Port of lib/features/booking/domain/entities/flight_carrier_model.dart

import Foundation

/// An airline/carrier available in the public flight catalogue.
struct FlightCarrierModel: Hashable {
    let code: String
    let name: String
    let logoUrl: String
    let bookable: Bool

    init(code: String, name: String, logoUrl: String, bookable: Bool) {
        self.code = code
        self.name = name
        self.logoUrl = logoUrl
        self.bookable = bookable
    }

    static func fromJson(_ json: JSON) -> FlightCarrierModel {
        FlightCarrierModel(
            code: Dart.str(json["code"]) ?? "",
            name: Dart.str(json["name"]) ?? "",
            logoUrl: Dart.str(json["logoUrl"]) ?? "",
            bookable: Dart.bool(json["bookable"]) == true
        )
    }
}
