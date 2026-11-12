// Port of lib/features/member/domain/entities/membership_model.dart
import SwiftUI

/// Epic World loyalty tiers, ordered lowest → highest.
///
/// A member's tier is *derived from their points* via `tierForPoints`; each
/// step up unlocks progressively better fares, support and rewards. Keep the
/// ordering of `values` ascending — `nextTierAfter` and the progress bar rely
/// on it.
enum MembershipTier: String, CaseIterable, DartEnum {
    case bronze, silver, gold, diamond
}

/// `extension MembershipTierMeta on MembershipTier`.
extension MembershipTier {
    /// Short display name, e.g. "Silver".
    var label: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .diamond: return "Diamond"
        }
    }

    /// Full name used on the member card, e.g. "Silver Member".
    var memberTitle: String { "\(label) Member" }

    /// Points required to *enter* this tier. Used both to pick a member's tier
    /// and to size the progress bar toward the next one.
    var minPoints: Int {
        switch self {
        case .bronze: return 0
        case .silver: return 3000
        case .gold: return 6000
        case .diamond: return 10000
        }
    }

    /// One-line pitch shown under the points pill on the tier cards.
    var tagline: String {
        switch self {
        case .bronze: return "Start earning points on every booking."
        case .silver: return "Priority support and member-only fares."
        case .gold: return "Premium perks and bigger savings."
        case .diamond: return "Our highest rewards and VIP treatment."
        }
    }

    var icon: IconData {
        switch self {
        case .bronze: return Icons.workspace_premium_rounded
        case .silver: return Icons.star_rounded
        case .gold: return Icons.emoji_events_rounded
        case .diamond: return Icons.diamond_rounded
        }
    }

    /// Card / badge gradient that gives each tier its own identity colour.
    var gradient: [Color] {
        switch self {
        case .bronze: return [Color(0xFFF08A24), Color(0xFFC2410C)]
        case .silver: return [Color(0xFFAAB2BE), Color(0xFF6B7684)]
        case .gold: return [Color(0xFFF7C04A), Color(0xFFE08A1E)]
        case .diamond: return [Color(0xFF4FC3F7), Color(0xFF2E7DD2)]
        }
    }

    /// Solid tint used for this tier's chips / labels / accent bar.
    var accent: Color {
        switch self {
        case .bronze: return Color(0xFFCF6A16)
        case .silver: return Color(0xFF64748B)
        case .gold: return Color(0xFFE8960F)
        case .diamond: return Color(0xFF2E8BD6)
        }
    }

    /// The "MOST POPULAR" highlight tier (matches the marketing plan grid).
    var isPopular: Bool { self == .gold }
}

/// The tier a member sitting on `points` currently belongs to.
func tierForPoints(_ points: Int) -> MembershipTier {
    var current = MembershipTier.bronze
    for t in MembershipTier.values {
        if points >= t.minPoints { current = t }
    }
    return current
}

/// The next tier up from `tier`, or nil once at the top (`MembershipTier.diamond`).
func nextTierAfter(_ tier: MembershipTier) -> MembershipTier? {
    let values = MembershipTier.values
    let i = values.firstIndex(of: tier) ?? -1
    return i + 1 < values.count ? values[i + 1] : nil
}

/// One perk row in the "Member Benefits" section.
struct MemberBenefit {
    let icon: IconData
    let title: String
    let subtitle: String

    init(icon: IconData, title: String, subtitle: String) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }
}

/// The coloured category pill on a partner card ("HOTELS", "DINING", …).
struct PartnerCategory {
    let label: String
    let color: Color

    init(_ label: String, _ color: Color) {
        self.label = label
        self.color = color
    }
}

/// A tier-specific saving offered by a partner brand, e.g. 20% "off + free
/// breakfast" for Diamond members.
struct PartnerOffer {
    let tier: MembershipTier

    /// The headline number, rendered large and bold.
    let percent: Int

    /// What the percentage applies to, e.g. "off room rates".
    let detail: String

    init(tier: MembershipTier, percent: Int, detail: String) {
        self.tier = tier
        self.percent = percent
        self.detail = detail
    }
}

/// A brand in the "Perks from our partner brands" section — a Gold & Diamond
/// exclusive: a photo card with the brand pitch, its per-tier savings and the
/// member code to quote at checkout.
struct PartnerBrand {
    let id: String
    let name: String
    let description: String
    let imageUrl: String
    let category: PartnerCategory

    /// Savings by tier, listed in the order they should render (Gold first).
    let offers: [PartnerOffer]

    /// Footnote about the brand's reach, e.g. "6 properties nationwide".
    let footnote: String

    /// Member code shown in the card's copy chip, e.g. "EPICSTAY".
    let code: String

    init(
        id: String,
        name: String,
        description: String,
        imageUrl: String,
        category: PartnerCategory,
        offers: [PartnerOffer],
        footnote: String,
        code: String
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.imageUrl = imageUrl
        self.category = category
        self.offers = offers
        self.footnote = footnote
        self.code = code
    }
}
