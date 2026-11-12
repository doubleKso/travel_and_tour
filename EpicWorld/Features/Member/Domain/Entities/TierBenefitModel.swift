// Port of lib/features/member/domain/entities/tier_benefit_model.dart
import Foundation

/// An active percentage discount for a service at a membership tier.
struct TierBenefitModel {
    let tierId: String
    let service: String
    let discountPct: Double

    init(tierId: String, service: String, discountPct: Double) {
        self.tierId = tierId
        self.service = service
        self.discountPct = discountPct
    }

    static func fromJson(_ json: JSON) -> TierBenefitModel {
        TierBenefitModel(
            tierId: Dart.str(json["tierId"]) ?? "",
            service: Dart.str(json["service"]) ?? "",
            discountPct: Dart.double(json["discountPct"]) ?? 0
        )
    }
}

/// Benefits applicable to one live membership tier.
///
/// The catalogue endpoint returns active benefits across every tier. Matching
/// IDs case-insensitively keeps the customer view stable when an environment
/// changes UUID casing or returns incidental whitespace.
func benefitsForTier(_ benefits: [TierBenefitModel], _ tierId: String) -> [TierBenefitModel] {
    let currentTierId = tierId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if currentTierId.isEmpty { return [] }
    return benefits.filter {
        $0.tierId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == currentTierId
    }
}
