// Port of test/features/ticket/presentation/widgets/eticket_card_payment_summary_test.dart
//
// The Dart file is a widget test; its assertions are on the amounts and labels
// `_PaymentSummary` computes, ported here against `ETicketCard.paymentSummary`
// and the exact strings the card renders from it.
import XCTest
@testable import EpicWorld

private func ticket(
    id: String,
    totalPaid: Double,
    discount: Double = 0,
    promotion: Double = 0,
    promoCode: String = ""
) -> TicketModel {
    TicketModel(
        id: id,
        bookingReference: "EW-\(id)",
        outbound: TripOptionModel(
            id: "myanmar-8M233",
            mode: .flight,
            operatorName: "Myanmar Airways",
            operatorLogoUrl: "",
            carrierCode: "8M",
            originCode: "RGN",
            originName: "Yangon",
            destinationCode: "SIN",
            destinationName: "Singapore",
            departure: DateTime(2026, 10, 23, 7, 25),
            arrival: DateTime(2026, 10, 23, 12, 5),
            stops: 0,
            travelClass: .economy,
            price: 492507,
            currency: "MMK",
            bookable: true
        ),
        inbound: nil,
        passengerName: "Mrs Myet Noe",
        seatCount: 1,
        totalPaid: totalPaid,
        currency: "MMK",
        issuedAt: DateTime(2026, 10, 20, 9, 30),
        qrPayload: "PNR|EW-\(id)",
        discount: discount,
        promotion: promotion,
        promoCode: promoCode
    )
}

/// The value the card draws for a deduction line.
private func minus(_ amount: Double) -> String { "− \(Formatters.price(amount, "MMK"))" }

final class EticketCardPaymentSummaryTests: XCTestCase {
    @MainActor
    func testPromoBookingShowsTheFareBeforeThePromoTheSavingAndWhatWasCharged() {
        // History: the record keeps the promotion, not the code.
        let t = ticket(id: "PROMO1", totalPaid: 197, discount: 492310, promotion: 492310)
        let summary = ETicketCard.paymentSummary(t)

        XCTAssertEqual(Formatters.price(summary.fare, t.currency), "492,507 MMK") // Fare / Total before discounts
        XCTAssertEqual(summary.promoLabel, LocaleKeys.booking_promo_code.tr())
        XCTAssertEqual(minus(summary.promotion), "− 492,310 MMK")
        XCTAssertEqual(summary.otherDiscount, 0)
        XCTAssertEqual(Formatters.price(t.totalPaid, t.currency), "197 MMK")
    }

    @MainActor
    func testAKnownPromoCodeIsNamed() {
        // Paid in-app with a promo code: the code is known.
        let t = ticket(id: "CODE1", totalPaid: 442507, discount: 50000, promotion: 50000, promoCode: "EPIC50")
        let summary = ETicketCard.paymentSummary(t)

        XCTAssertEqual(summary.promoLabel, "\(LocaleKeys.booking_promo_code.tr()) (EPIC50)")
        XCTAssertEqual(minus(summary.promotion), "− 50,000 MMK")
        XCTAssertEqual(Formatters.price(t.totalPaid, t.currency), "442,507 MMK")
    }

    @MainActor
    func testRewardPointsAreADiscountNotAPromo() {
        // Paid with reward points: a discount, not a promo.
        let t = ticket(id: "PTS1", totalPaid: 482507, discount: 10000)
        let summary = ETicketCard.paymentSummary(t)

        XCTAssertEqual(Formatters.price(summary.fare, t.currency), "492,507 MMK")
        XCTAssertEqual(minus(summary.otherDiscount), "− 10,000 MMK")
        // No promo line.
        XCTAssertEqual(summary.promotion, 0)
    }

    @MainActor
    func testNoDiscountShowsJustTheFareAndTheTotalPaid() {
        let t = ticket(id: "PLAIN1", totalPaid: 492507)
        let summary = ETicketCard.paymentSummary(t)

        XCTAssertEqual(Formatters.price(summary.fare, t.currency), "492,507 MMK")
        XCTAssertEqual(Formatters.price(t.totalPaid, t.currency), "492,507 MMK")
        // No "Total before discounts" block.
        XCTAssertFalse(summary.promotion > 0 || summary.otherDiscount > 0)
    }
}
