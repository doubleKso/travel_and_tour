// Port of lib/features/booking/domain/entities/global_airline_rate_model.dart

import Foundation

/// The public commission/markup rate configured for a carrier.
struct GlobalAirlineRateModel: Hashable {
    let carrierCode: String
    let ratePct: Double

    init(carrierCode: String, ratePct: Double) {
        self.carrierCode = carrierCode
        self.ratePct = ratePct
    }

    static func fromJson(_ json: JSON) -> GlobalAirlineRateModel {
        GlobalAirlineRateModel(
            carrierCode: Dart.str(json["carrierCode"]) ?? "",
            ratePct: Dart.double(json["ratePct"]) ?? 0
        )
    }
}
