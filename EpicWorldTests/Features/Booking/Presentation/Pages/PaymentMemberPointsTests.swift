import XCTest
@testable import EpicWorld

/// Ports the logic of
/// test/features/booking/presentation/pages/payment_member_points_test.dart
/// (the grouped point balance, and Use staging it as the reward deduction),
/// plus the guards around point redemption and promo codes in
/// `_PaymentScreenState` that the widget test exercises through taps.
///
/// Not ported: "payment entry must refresh /myPoints" — it needs a signed-in
/// `AuthNotifier`, which belongs to the auth port; and
/// payment_back_confirm_test.dart, which only asserts dialog widgets.
@MainActor
final class PaymentMemberPointsTests: XCTestCase {
    private func makeState(baseTotal: Double = 375_435) -> PaymentPage.PaymentScreenState {
        let state = PaymentPage.PaymentScreenState(
            container: AppContainer(),
            router: AppRouter(),
            entryID: nil
        )
        state.baseTotal = baseTotal
        return state
    }

    func testGroupsTheMemberPointBalance() {
        XCTAssertEqual(PaymentPage.PaymentScreenState.pointsLabel(1_234_567), "1,234,567 points")
        XCTAssertEqual(PaymentPage.PaymentScreenState.pointsLabel(7), "7 points")
    }

    func testUseStagesTheWholeBalanceCappedAtWhatIsOwed() {
        let state = makeState()
        state.pointsExpanded = true

        state.usePoints(1_234_567)

        XCTAssertTrue(state.pointsApplied)
        XCTAssertFalse(state.pointsExpanded)
        XCTAssertEqual(state.selectedPoints, 1_234_567)
        XCTAssertNil(state.redeemedPointsDiscount)
        // 1 pt = 1 MMK, but the grand total can never go negative.
        XCTAssertEqual(state.rewardValue, 375_435)
        XCTAssertEqual(state.baseTotal - state.discount - state.rewardValue, 0)
    }

    func testUseIsRefusedWhileAPromoCodeIsApplied() {
        let state = makeState()
        state.appliedCode = "EPIC10"

        state.usePoints(500)

        XCTAssertFalse(state.pointsApplied)
        XCTAssertEqual(state.selectedPoints, 0)
    }

    func testUseIsRefusedWithoutABalance() {
        let state = makeState()

        state.usePoints(0)

        XCTAssertFalse(state.pointsApplied)
    }

    func testPromoCodesAndPointsDoNotStack() {
        let state = makeState(baseTotal: 1000)
        state.pointsApplied = true
        state.selectedPoints = 300
        XCTAssertEqual(state.rewardValue, 300)

        state.appliedCode = "EPIC10"
        state.discount = 100

        XCTAssertEqual(state.rewardValue, 0)
    }

    func testTheRedeemedDiscountReplacesTheStagedPoints() {
        let state = makeState(baseTotal: 1000)
        state.pointsApplied = true
        state.selectedPoints = 500
        state.redeemedPointsDiscount = 320

        XCTAssertEqual(state.rewardValue, 320)
    }

    func testRemoveClearsStagedPoints() {
        let state = makeState()
        state.usePoints(900)

        state.removePoints()

        XCTAssertFalse(state.pointsApplied)
        XCTAssertEqual(state.selectedPoints, 0)
        XCTAssertEqual(state.rewardValue, 0)
    }

    func testRedeemedPointsCannotBeRemovedOrCombinedWithAPromo() async {
        let state = makeState()
        state.usePoints(900)
        state.pointsRedeemedForBookingId = "booking-1"
        state.promoText = "EPIC10"

        state.removePoints()
        XCTAssertTrue(state.pointsApplied, "points already spent on the booking stay applied")

        // Refused before any network call is attempted.
        await state.applyPromo(state.baseTotal)
        XCTAssertNil(state.appliedCode)
        XCTAssertFalse(state.applyingPromo)
    }

    func testAnEmptyPromoCodeIsRefusedLocally() async {
        let state = makeState()
        state.promoText = "   "

        await state.applyPromo(state.baseTotal)

        XCTAssertNil(state.appliedCode)
        XCTAssertFalse(state.applyingPromo)
    }

    func testPromoSubtotalIsSentWithoutTrailingZeros() {
        XCTAssertEqual(PaymentPage.PaymentScreenState.subtotalForPromo(375_435), "375435")
        XCTAssertEqual(PaymentPage.PaymentScreenState.subtotalForPromo(1000), "1000")
        XCTAssertEqual(PaymentPage.PaymentScreenState.subtotalForPromo(12.5), "12.50")
        XCTAssertEqual(PaymentPage.PaymentScreenState.subtotalForPromo(99.999), "100.00")
    }

    func testHeldContactValuesAreTrimmedAndBlankIsAbsent() {
        let contact: JSON = ["fullName": "  MTester one  ", "phone": "   ", "email": "a@b.co"]

        XCTAssertEqual(PaymentPage.PaymentScreenState.contactValue(contact, "fullName"), "MTester one")
        XCTAssertNil(PaymentPage.PaymentScreenState.contactValue(contact, "phone"))
        XCTAssertNil(PaymentPage.PaymentScreenState.contactValue(contact, "countryCode"))
        XCTAssertNil(PaymentPage.PaymentScreenState.contactValue(nil, "email"))
    }
}
