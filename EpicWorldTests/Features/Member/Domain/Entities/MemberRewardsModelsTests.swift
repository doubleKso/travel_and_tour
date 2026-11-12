// Port of test/features/member/domain/entities/member_rewards_models_test.dart
import XCTest
@testable import EpicWorld

final class MemberRewardsModelsTests: XCTestCase {
    func testMapsDiscountTiersReturnedByGetDiscountTiers() {
        let tier = DiscountTier.fromJson([
            "id": "1f6144c9579a4bf7b53a61aa9f89c06d",
            "code": "BRONZE",
            "name": "BRZ",
            "ratePct": 10,
            "active": true,
            "minDeposit": 0,
        ])

        XCTAssertEqual(tier.code, "BRONZE")
        XCTAssertEqual(tier.name, "BRZ")
        XCTAssertEqual(tier.ratePct, 10)
        XCTAssertTrue(tier.active)
    }

    func testMapsNestedMyPointsDataAndStringBalances() {
        let balance = MemberPointBalance.fromJson([
            "data": ["balance": "3450"],
        ])

        XCTAssertEqual(balance.points, 3450)
    }

    func testSerializesRedeemPointsRequestUsingBookingIdAndStringPoints() {
        let request = RedeemPointsRequest(
            accessToken: "session-token",
            bookingId: "booking-123",
            points: "3450"
        )

        XCTAssertEqual(request.toJson() as NSDictionary, [
            "accessToken": "session-token",
            "bookingId": "booking-123",
            "points": "3450",
        ] as NSDictionary)
    }

    func testMapsRedeemPointsResult() {
        let result = RedeemPointsResponse.fromJson([
            "ok": true,
            "redeemed": 3000,
            "discount": 3000,
            "balance": 450,
        ])

        XCTAssertTrue(result.ok)
        XCTAssertEqual(result.redeemed, 3000)
        XCTAssertEqual(result.discount, 3000)
        XCTAssertEqual(result.balance, 450)
    }

    func testMapsGetMeAccountDataAndPointLedgerTransactions() {
        let account = MemberAccount.fromJson([
            "id": "member-1",
            "publicId": "EW-1001",
            "email": "member@example.com",
            "phone": "+959123456789",
            "name": "Epic Member",
            "tier": "gold",
            "points": "1200",
            "lifetimePoints": 4900,
            "avatarUrl": "https://example.com/avatar.png",
        ])
        let transaction = PointLedgerTransaction.fromJson([
            "id": "ledger-1",
            "type": "earn",
            "points": 200,
            "balanceAfter": 1200,
            "source": "booking",
            "createdAt": "2026-09-16T02:13:27.651Z",
            "remainingPoints": 1200,
        ])

        XCTAssertEqual(account.name, "Epic Member")
        XCTAssertEqual(account.phone, "+959123456789")
        XCTAssertEqual(account.tier, "gold")
        XCTAssertEqual(account.lifetimePoints, 4900)
        XCTAssertEqual(transaction.balanceAfter, 1200)
        XCTAssertNotNil(transaction.createdAt)
    }
}
