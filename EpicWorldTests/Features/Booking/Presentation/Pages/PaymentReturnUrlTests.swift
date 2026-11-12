import XCTest
@testable import EpicWorld

/// Ports test/features/booking/presentation/pages/payment_return_url_test.dart.
@MainActor
final class PaymentReturnUrlTests: XCTestCase {
    func testRecognisesSmartPayHandingTheCustomerBack() {
        for url in [
            // The backend's configured SMARTPAY_RETURN_URL.
            "https://epicworld-fad26.web.app/booking/payment/return",
            "https://epicworld-fad26.web.app/booking/payment/return?status=PAID",
            "https://epicworld.com.mm/booking/payment/return?order=EW-QSGD99-1",
            // The path alone, which is what the platform hands a warm deep link.
            "/booking/payment/return",
            // Tolerated in case the web build serves hash routes, or the return
            // URL moves under a path prefix.
            "https://epicworld-fad26.web.app/#/booking/payment/return",
            "https://epicworld-fad26.web.app/#/booking/payment/return?status=FAILED",
            "https://epicworld.com.mm/app/booking/payment/return",
            "https://EpicWorld.com.mm/Booking/Payment/Return",
        ] {
            let parsed = URL(string: url)
            XCTAssertNotNil(parsed, "\(url) must parse")
            guard let parsed else { continue }
            XCTAssertTrue(
                PaymentReturnPage.isReturnUrl(parsed),
                "expected \(url) to be treated as the payment return"
            )
        }
    }

    func testLeavesEveryOtherLinkAlone() {
        for url in [
            "https://pay-uat.smarticwork.com/payment?id=123",
            "https://pano-uat.smarticwork.com/api/v1/payment-requests",
            // Near-misses that must not be mistaken for the return URL.
            "https://pay-uat.smarticwork.com/booking/payment/returning",
            "https://epicworld-fad26.web.app/booking/payment",
            "https://epicworld-fad26.web.app/booking/completed",
            "/home",
            "/",
        ] {
            let parsed = URL(string: url)
            XCTAssertNotNil(parsed, "\(url) must parse")
            guard let parsed else { continue }
            XCTAssertFalse(
                PaymentReturnPage.isReturnUrl(parsed),
                "expected \(url) to route normally"
            )
        }
    }

    func testTheRouteRegisteredInTheRouterIsTheOneTheBackendCalls() {
        // SMARTPAY_RETURN_URL is https://epicworld-fad26.web.app + this path.
        XCTAssertEqual(PaymentReturnPage.routePath, "/booking/payment/return")
        XCTAssertEqual(Route.paymentReturn.path, "/booking/payment/return")
    }
}
