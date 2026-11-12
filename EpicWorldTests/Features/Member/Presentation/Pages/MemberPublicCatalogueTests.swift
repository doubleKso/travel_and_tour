// Port of test/features/member/presentation/pages/member_public_catalogue_test.dart
import SwiftUI
import UIKit
import XCTest
@testable import EpicWorld

final class MemberPublicCatalogueTests: XCTestCase {
    /// Flutter's `color.toARGB32()`.
    private func argb32(_ color: Color) -> UInt32 {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        func channel(_ value: CGFloat) -> UInt32 { UInt32((value * 255).rounded()) }
        return channel(a) << 24 | channel(r) << 16 | channel(g) << 8 | channel(b)
    }

    @MainActor
    func testMemberPageCompilesWithTheLiveLoyaltyCatalogue() {
        let page = MemberPage()
        XCTAssertNil(page.onBack)
    }

    func testMapsLiveMembershipTiersAndResolvesThresholdsByRank() {
        let tiers = [
            MembershipTierData.fromJson([
                "id": "bronze-id",
                "code": "BRZ",
                "name": "Bronze",
                "rank": 0,
                "requiredPoints": 0,
                "icon": "compass",
                "color": "#cd7f32",
                "tagline": "Start earning points on every booking.",
            ]),
            MembershipTierData.fromJson([
                "id": "silver-id",
                "code": "SILVER",
                "name": "Silver",
                "rank": 1,
                "requiredPoints": 3000,
                "icon": "medal",
                "color": "#c0c0c0",
                "tagline": "Priority support and member-only fares.",
            ]),
        ]

        XCTAssertEqual(tierForLivePoints(3500, tiers)?.name, "Silver")
        XCTAssertEqual(nextLiveTierAfter(tiers[0], tiers)?.name, "Silver")
        XCTAssertEqual(argb32(tiers[0].accent), 0xFFCD7F32)
    }

    func testMapsAnActiveTierBenefit() {
        let benefit = TierBenefitModel.fromJson([
            "tierId": "silver-id",
            "service": "flight",
            "discountPct": 3,
        ])

        XCTAssertEqual(benefit.tierId, "silver-id")
        XCTAssertEqual(benefit.service, "flight")
        XCTAssertEqual(benefit.discountPct, 3)
    }

    func testShowsOnlyBenefitsBelongingToTheCurrentTier() {
        let benefits = [
            TierBenefitModel(tierId: "bronze-id", service: "flight", discountPct: 1),
            TierBenefitModel(tierId: " SILVER-ID ", service: "hotel", discountPct: 4),
            TierBenefitModel(tierId: "gold-id", service: "tour", discountPct: 7),
        ]

        let visible = benefitsForTier(benefits, "silver-id")

        XCTAssertEqual(visible.count, 1)
        XCTAssertEqual(visible.first?.service, "hotel")
    }

    func testMapsAndFiltersTitledActiveTierPerks() {
        let perk = TierPerkModel.fromJson([
            "id": "perk-1",
            "tierId": "gold-id",
            "icon": "ticket",
            "title": "Member-only fares",
            "detail": "Exclusive discounts on flights and tours.",
        ])

        let visible = perksForTier([perk], " GOLD-ID ")

        XCTAssertEqual(visible.count, 1)
        XCTAssertEqual(visible.first?.title, "Member-only fares")
    }

    func testUsesTheTierReturnedByGetMeWhenItMatchesTheCatalogue() {
        let tiers = [
            MembershipTierData.fromJson([
                "id": "bronze-id",
                "code": "BRZ",
                "name": "Bronze",
                "rank": 0,
                "requiredPoints": 0,
            ]),
            MembershipTierData.fromJson([
                "id": "gold-id",
                "code": "GOLD",
                "name": "Gold",
                "rank": 2,
                "requiredPoints": 10000,
            ]),
        ]

        XCTAssertEqual(
            tierForMember(reportedTier: "GOLD", points: 0, tiers: tiers)?.name,
            "Gold"
        )
    }

    func testMapsGlobalAndTierSpecificAirlineRates() {
        let global = GlobalAirlineRateModel.fromJson([
            "carrierCode": "MAI",
            "ratePct": 5,
        ])
        let tier = TierAirlineRateModel.fromJson([
            "tierId": "silver-id",
            "carrierCode": "MAI",
            "ratePct": 8,
        ])

        XCTAssertEqual(global.carrierCode, "MAI")
        XCTAssertEqual(global.ratePct, 5)
        XCTAssertEqual(tier.tierId, "silver-id")
        XCTAssertEqual(tier.ratePct, 8)
    }
}
