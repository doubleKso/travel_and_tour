// Port of lib/features/member/data/datasources/member_mock_service.dart
import SwiftUI

/// Hard-coded content for the Member tab (benefits + partner-brand perks) so
/// the screen is fully runnable before the real loyalty API is wired in. Swap
/// these for repository calls once the backend exists.
struct MemberMockService {
    init() {}

    /// Instance API used by `MemberRepositoryImpl`.
    func getBenefits() -> [MemberBenefit] { Self.benefits }

    func getPartners() -> [PartnerBrand] { Self.partners }

    /// The four headline perks in the "Member Benefits" section.
    static let benefits: [MemberBenefit] = [
        MemberBenefit(
            icon: Icons.confirmation_number_outlined,
            title: "Member-only fares",
            subtitle: "Exclusive discounts on flights & tours."
        ),
        MemberBenefit(
            icon: Icons.bolt_outlined,
            title: "Priority support",
            subtitle: "Skip the queue with dedicated assistance."
        ),
        MemberBenefit(
            icon: Icons.card_giftcard_outlined,
            title: "Earn & redeem points",
            subtitle: "Every booking earns points toward free travel."
        ),
        MemberBenefit(
            icon: Icons.badge_outlined,
            title: "Faster visa processing",
            subtitle: "Members get expedited handling."
        ),
    ]

    // Category pills used across the partner cards.
    private static let hotels = PartnerCategory("HOTELS", Color(0xFFE8802B))
    private static let dining = PartnerCategory("DINING", Color(0xFFE23B62))
    private static let wellness = PartnerCategory("WELLNESS", Color(0xFF16A34A))
    private static let lifestyle = PartnerCategory("LIFESTYLE", Color(0xFF3B9DE8))
    private static let transport = PartnerCategory("TRANSPORT", Color(0xFF8B5CF6))
    private static let shopping = PartnerCategory("SHOPPING", Color(0xFF65A30D))

    /// Gold & Diamond exclusive partner brands ("Perks from our partner brands").
    static let partners: [PartnerBrand] = [
        PartnerBrand(
            id: "p1",
            name: "Aurora Grand Hotels",
            description:
                "Five-star stays in Yangon, Mandalay and Ngapali with late "
                + "checkout for members.",
            imageUrl:
                "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800",
            category: hotels,
            offers: [
                PartnerOffer(
                    tier: .gold,
                    percent: 12,
                    detail: "off room rates"
                ),
                PartnerOffer(
                    tier: .diamond,
                    percent: 20,
                    detail: "off + free breakfast"
                ),
            ],
            footnote: "6 properties nationwide",
            code: "EPICSTAY"
        ),
        PartnerBrand(
            id: "p2",
            name: "Thurain Fine Dining",
            description:
                "Modern Burmese tasting menus and a rooftop grill overlooking "
                + "the lake.",
            imageUrl:
                "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800",
            category: dining,
            offers: [
                PartnerOffer(
                    tier: .gold,
                    percent: 10,
                    detail: "off the total bill"
                ),
                PartnerOffer(
                    tier: .diamond,
                    percent: 18,
                    detail: "off + welcome drink"
                ),
            ],
            footnote: "4 restaurants in Yangon",
            code: "EPICDINE"
        ),
        PartnerBrand(
            id: "p3",
            name: "Golden Bell Spa",
            description:
                "Traditional massage, herbal therapy and post-flight recovery "
                + "treatments.",
            imageUrl:
                "https://images.unsplash.com/photo-1544161515-4ab6ce6db874?w=800",
            category: wellness,
            offers: [
                PartnerOffer(
                    tier: .gold,
                    percent: 15,
                    detail: "off all treatments"
                ),
                PartnerOffer(
                    tier: .diamond,
                    percent: 25,
                    detail: "off + 30 min extra"
                ),
            ],
            footnote: "9 branches nationwide",
            code: "EPICSPA"
        ),
        PartnerBrand(
            id: "p4",
            name: "Skyline Airport Lounge",
            description:
                "Quiet lounge access with hot meals, showers and fast Wi-Fi "
                + "before departure.",
            imageUrl:
                "https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=800",
            category: lifestyle,
            offers: [
                PartnerOffer(
                    tier: .gold,
                    percent: 25,
                    detail: "off day passes"
                ),
                PartnerOffer(
                    tier: .diamond,
                    percent: 100,
                    detail: "off — 2 free visits a year"
                ),
            ],
            footnote: "2 lounges at Yangon International",
            code: "EPICLOUNGE"
        ),
        PartnerBrand(
            id: "p5",
            name: "Silverline Car Rental",
            description:
                "Airport transfers and self-drive rentals with free delivery to "
                + "your hotel.",
            imageUrl:
                "https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=800",
            category: transport,
            offers: [
                PartnerOffer(
                    tier: .gold,
                    percent: 10,
                    detail: "off every rental"
                ),
                PartnerOffer(
                    tier: .diamond,
                    percent: 18,
                    detail: "off + free airport transfer"
                ),
            ],
            footnote: "Yangon, Mandalay & Naypyitaw",
            code: "EPICDRIVE"
        ),
        PartnerBrand(
            id: "p6",
            name: "Metro Mart",
            description:
                "Groceries, travel essentials and duty-free pickup before you fly.",
            imageUrl:
                "https://images.unsplash.com/photo-1542838132-92c53300491e?w=800",
            category: shopping,
            offers: [
                PartnerOffer(
                    tier: .gold,
                    percent: 8,
                    detail: "off travel essentials"
                ),
                PartnerOffer(
                    tier: .diamond,
                    percent: 15,
                    detail: "off + free home delivery"
                ),
            ],
            footnote: "20 stores nationwide",
            code: "EPICMART"
        ),
    ]
}
