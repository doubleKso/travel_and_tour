// Port of lib/features/booking/domain/entities/tier_airline_rate_model.dart

import Foundation

/// A carrier rate that overrides the global rate for one membership tier.
struct TierAirlineRateModel: Hashable {
    let tierId: String
    let carrierCode: String
    let ratePct: Double

    init(tierId: String, carrierCode: String, ratePct: Double) {
        self.tierId = tierId
        self.carrierCode = carrierCode
        self.ratePct = ratePct
    }

    static func fromJson(_ json: JSON) -> TierAirlineRateModel {
        TierAirlineRateModel(
            tierId: Dart.str(json["tierId"]) ?? "",
            carrierCode: Dart.str(json["carrierCode"]) ?? "",
            ratePct: Dart.double(json["ratePct"]) ?? 0
        )
    }
}
