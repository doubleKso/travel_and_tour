import XCTest
@testable import EpicWorld

/// Port of test/features/booking/data/datasources/promo_code_models_test.dart.
final class PromoCodeModelsTests: XCTestCase {
    func testSerializesTheCheckPromoCodeCallablePayload() {
        let request = PromoCodeCheckRequest(
            code: "SBS",
            accessToken: "session-access-token",
            subtotal: "505818",
            email: "traveller@example.com"
        )

        XCTAssertEqual(
            NSDictionary(dictionary: request.toJson()),
            NSDictionary(dictionary: [
                "code": "SBS",
                "accessToken": "session-access-token",
                "subtotal": "505818",
                "email": "traveller@example.com",
            ])
        )
    }

    func testMapsASuccessfulCheckPromoCodeResponse() {
        let response = PromoCodeCheckResponse.fromJson([
            "ok": true,
            "code": "SBS",
            "amount": 505515,
            "kind": "percent",
            "value": 99.94,
            "minSpend": 0,
            "reason": "ok",
            "message": "Promo \"SBS\" applied!",
        ])

        XCTAssertTrue(response.ok)
        XCTAssertEqual(response.code, "SBS")
        XCTAssertEqual(response.amount, 505515)
        XCTAssertEqual(response.kind, "percent")
        XCTAssertEqual(response.value, 99.94)
        XCTAssertEqual(response.message, "Promo \"SBS\" applied!")
        // `expect(PromoCodeCallableService, isNotNull)`; the provider is
        // `AppContainer.promoCodeCallableService`.
        XCTAssertNotNil(PromoCodeCallableService.self)
    }
}
