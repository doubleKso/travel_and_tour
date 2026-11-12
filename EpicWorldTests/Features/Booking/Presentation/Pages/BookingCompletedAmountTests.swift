import XCTest
@testable import EpicWorld

/// Ports the logic of
/// test/features/booking/presentation/pages/booking_completed_amount_test.dart:
/// the Amount Detail sheet's figures for a ticket bought with a promo code
/// (279 MMK fare, 50 off, 229 charged). The widget-finder plumbing is not
/// ported; the sheet's own values are checked directly.
@MainActor
final class BookingCompletedAmountTests: XCTestCase {
    func testTheAmountSummaryShowsThePromoCodeAndItsDiscount() {
        let sheet = BookingCompletedPage.AmountDetailSheet(
            total: 229,
            discount: 50,
            promoCode: "EPIC50",
            adults: 1
        )

        // The fare before the promo, the saving, the code, and what was charged.
        XCTAssertEqual(sheet.subTotal, 279)
        XCTAssertEqual(sheet.subTotalValue, "279 MMK")
        XCTAssertEqual(sheet.discountValue, "− 50 MMK")
        XCTAssertEqual(sheet.promoValue, "EPIC50")
        XCTAssertEqual(sheet.grandTotalValue, "229 MMK")
    }

    func testNoPromoCodeShowsADash() {
        let sheet = BookingCompletedPage.AmountDetailSheet(
            total: 375_435,
            discount: 0,
            promoCode: "",
            adults: 2
        )

        XCTAssertEqual(sheet.promoValue, "-")
        XCTAssertEqual(sheet.subTotalValue, "375,435 MMK")
        XCTAssertEqual(sheet.discountValue, "− 0 MMK")
    }
}
