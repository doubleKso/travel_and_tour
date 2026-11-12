// Port of lib/features/member/domain/entities/tier_perk_model.dart
import Foundation

/// A titled membership perk returned by `dcExec:GetActiveTierPerks`.
struct TierPerkModel {
    let id: String
    let tierId: String
    let icon: String
    let title: String
    let detail: String

    init(id: String, tierId: String, icon: String, title: String, detail: String) {
        self.id = id
        self.tierId = tierId
        self.icon = icon
        self.title = title
        self.detail = detail
    }

    static func fromJson(_ json: JSON) -> TierPerkModel {
        TierPerkModel(
            id: Dart.str(json["id"]) ?? "",
            tierId: Dart.str(json["tierId"]) ?? "",
            icon: Dart.str(json["icon"]) ?? "",
            title: Dart.str(json["title"]) ?? "",
            detail: Dart.str(json["detail"]) ?? ""
        )
    }
}

/// Filters perks for a tier without assuming UUID casing or whitespace.
func perksForTier(_ perks: [TierPerkModel], _ tierId: String) -> [TierPerkModel] {
    let normalizedTierId = tierId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if normalizedTierId.isEmpty { return [] }
    return perks.filter {
        $0.tierId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedTierId
    }
}
