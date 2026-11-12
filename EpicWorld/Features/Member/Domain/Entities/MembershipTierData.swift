// Port of lib/features/member/domain/entities/membership_tier_data.dart
import SwiftUI

/// A loyalty tier returned by `GetMembershipTiers`.
///
/// Dart compares these by identity (the class has no `==`); value equality
/// is used here, which only differs if the catalogue returned two tiers with
/// every field identical.
struct MembershipTierData: Equatable {
    let id: String
    let code: String
    let name: String
    let rank: Int
    let requiredPoints: Int
    let iconName: String
    let colorHex: String
    let tagline: String

    init(
        id: String,
        code: String,
        name: String,
        rank: Int,
        requiredPoints: Int,
        iconName: String,
        colorHex: String,
        tagline: String
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.rank = rank
        self.requiredPoints = requiredPoints
        self.iconName = iconName
        self.colorHex = colorHex
        self.tagline = tagline
    }

    static func fromJson(_ json: JSON) -> MembershipTierData {
        MembershipTierData(
            id: Dart.str(json["id"]) ?? "",
            code: Dart.str(json["code"]) ?? "",
            name: Dart.str(json["name"]) ?? "",
            rank: Dart.int(json["rank"]) ?? 0,
            requiredPoints: Dart.int(json["requiredPoints"]) ?? 0,
            iconName: Dart.str(json["icon"]) ?? "",
            colorHex: Dart.str(json["color"]) ?? "",
            tagline: Dart.str(json["tagline"]) ?? ""
        )
    }

    var accent: Color {
        // RegExp(r'^#?([0-9a-fA-F]{6})$') — `\z` because Dart's `$` does not
        // match before a trailing newline the way ICU's does.
        guard colorHex.range(of: #"^#?[0-9a-fA-F]{6}\z"#, options: .regularExpression) != nil else {
            return AppTierColors.fallback
        }
        let hex = String(colorHex.suffix(6))
        guard let value = UInt32("FF\(hex)", radix: 16) else { return AppTierColors.fallback }
        return Color(value)
    }

    var gradient: [Color] { [accent.withValues(alpha: 0.78), accent] }

    var icon: IconData {
        switch iconName.lowercased() {
        case "compass": return Icons.explore_rounded
        case "medal": return Icons.military_tech_rounded
        case "trophy": return Icons.emoji_events_rounded
        case "gem": return Icons.diamond_rounded
        default: return Icons.workspace_premium_rounded
        }
    }

    var isPopular: Bool { code.uppercased() == "GOLD" }
}

/// `abstract final class AppTierColors`.
enum AppTierColors {
    static let fallback = Color(0xFF64748B)
}

/// Resolves a member's live tier against API point thresholds.
func tierForLivePoints(_ points: Int, _ tiers: [MembershipTierData]) -> MembershipTierData? {
    var current: MembershipTierData?
    for tier in tiers {
        if points >= tier.requiredPoints { current = tier }
    }
    return current
}

/// Resolves the tier reported by `GetMe` before falling back to point
/// thresholds. Environments may return a tier ID, code, or display name.
func tierForMember(
    reportedTier: String,
    points: Int,
    tiers: [MembershipTierData]
) -> MembershipTierData? {
    let value = reportedTier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if !value.isEmpty {
        for tier in tiers {
            if tier.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == value
                || tier.code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == value
                || tier.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == value {
                return tier
            }
        }
    }
    return tierForLivePoints(points, tiers)
}

func nextLiveTierAfter(
    _ tier: MembershipTierData,
    _ tiers: [MembershipTierData]
) -> MembershipTierData? {
    let index = tiers.firstIndex(of: tier) ?? -1
    return index >= 0 && index + 1 < tiers.count ? tiers[index + 1] : nil
}
