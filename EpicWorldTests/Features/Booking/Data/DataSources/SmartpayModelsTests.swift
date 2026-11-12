import XCTest
@testable import EpicWorld

/// Port of test/features/booking/data/datasources/smartpay_models_test.dart.
final class SmartpayModelsTests: XCTestCase {
    private static let suiteName = "EpicWorldTests.SmartpayModels"
    private var previousStore: UserDefaults!

    override func setUp() {
        super.setUp()
        previousStore = AppPrefs.store
        UserDefaults().removePersistentDomain(forName: Self.suiteName)
        AppPrefs.store = UserDefaults(suiteName: Self.suiteName)!
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: Self.suiteName)
        AppPrefs.store = previousStore
        super.tearDown()
    }

    func testCreatePaymentRequestMatchesTheDocumentedCallableBody() {
        let request = CreatePaymentIntentRequest(
            reference: "EW-QSGD99",
            accessToken: "session-token",
            email: "user@example.com",
            promoCode: "EPIC10"
        )

        XCTAssertEqual(
            NSDictionary(dictionary: request.toJson()),
            NSDictionary(dictionary: [
                "reference": "EW-QSGD99",
                "accessToken": "session-token",
                "email": "user@example.com",
                "promoCode": "EPIC10",
            ])
        )
    }

    func testCreatePaymentResponseParsesTheDocumentedResultFields() {
        let response = CreatePaymentIntentResponse.fromJson([
            "ok": true,
            "paymentUrl": "https://pay-uat.smarticwork.com/payment?id=123",
            "merchantOrderNo": "EW-QSGD99-1",
            "amount": 125000,
            "currency": "MMK",
            "payBefore": "2026-09-01T06:00:00Z",
            "reason": "",
            "message": "Created",
        ])

        XCTAssertTrue(response.ok)
        XCTAssertTrue(response.paymentUrl.hasPrefix("https://pay-uat.smarticwork.com"))
        XCTAssertEqual(response.merchantOrderNo, "EW-QSGD99-1")
        XCTAssertEqual(response.amount, 125000.0)
        XCTAssertEqual(response.currency, "MMK")
    }

    func testARefusedIntentExplainsItselfWithWhateverTheBackendSent() {
        func refused(message: String = "", reason: String = "") -> CreatePaymentIntentResponse {
            CreatePaymentIntentResponse.fromJson([
                "ok": false,
                "message": message,
                "reason": reason,
            ])
        }

        XCTAssertEqual(refused(message: "Booking already paid").failureMessage, "Booking already paid")
        XCTAssertEqual(refused(reason: "HOLD_EXPIRED").failureMessage, "HOLD_EXPIRED")
        XCTAssertEqual(refused().failureMessage, "SmartPay did not return a payment link.")
    }

    func testStatusRequestMatchesTheDocumentedCallableBody() {
        let request = GetPaymentStatusRequest(
            reference: "EW-QSGD99",
            accessToken: "",
            email: "guest@example.com"
        )

        XCTAssertEqual(
            NSDictionary(dictionary: request.toJson()),
            NSDictionary(dictionary: [
                "reference": "EW-QSGD99",
                "accessToken": "",
                "email": "guest@example.com",
            ])
        )
    }

    func testPaidIsSuccessfulOnlyAfterBackendTicketingCompletes() {
        func status(ticketed: Bool) -> GetPaymentStatusResponse {
            GetPaymentStatusResponse.fromJson([
                "ok": true,
                "status": "PAID",
                "bookingStatus": "CONFIRMED",
                "ticketed": ticketed,
                "amount": 125000,
                "currency": "MMK",
            ])
        }

        XCTAssertTrue(status(ticketed: true).isSuccessful)
        XCTAssertFalse(status(ticketed: false).isSuccessful)
        XCTAssertEqual(
            status(ticketed: false).displayMessage,
            "Payment was received and ticketing is still in progress."
        )
    }

    func testAPaidChargeTheBackendDisownsIsNotSuccess() {
        let status = GetPaymentStatusResponse.fromJson([
            "ok": false,
            "status": "PAID",
            "ticketed": true,
            "message": "Booking reference does not belong to this account.",
        ])

        XCTAssertFalse(status.isSuccessful)
        XCTAssertEqual(status.displayMessage, "Booking reference does not belong to this account.")
    }

    func testTerminalSmartPayStatesAreRecognisedPendingOnesAreNot() {
        func withStatus(_ value: String) -> GetPaymentStatusResponse {
            GetPaymentStatusResponse.fromJson(["ok": true, "status": value])
        }

        for value in ["FAILED", "EXPIRED", "CANCELLED", "CLOSED"] {
            XCTAssertTrue(withStatus(value).isTerminalFailure, value)
        }
        for value in ["PENDING", "PROCESSING", "CREATED", ""] {
            XCTAssertFalse(withStatus(value).isTerminalFailure, value)
        }
    }

    func testAPendingSmartPayChargeCanReopenCheckoutForTheSameBooking() {
        XCTAssertTrue(
            GetPaymentStatusResponse.fromJson([
                "ok": true,
                "status": "pending",
                "bookingStatus": "held",
            ]).canResumePayment
        )
        XCTAssertFalse(
            GetPaymentStatusResponse.fromJson([
                "ok": true,
                "status": "PAID",
                "ticketed": false,
            ]).canResumePayment,
            "a settled charge must remain in ticketing verification"
        )
        XCTAssertFalse(
            GetPaymentStatusResponse.fromJson([
                "ok": false,
                "status": "PENDING",
            ]).canResumePayment
        )
    }

    func testPendingReturnContextRoundTripsWithoutAnAccessToken() async {
        let payment = PendingSmartPayPayment(
            reference: "EW-QSGD99",
            email: "user@example.com",
            merchantOrderNo: "EW-QSGD99-1",
            startedAt: DateTime.utc(2026, 9, 1, 5, 30)
        )
        await PendingSmartPayPaymentStore.save(payment)

        let restored = PendingSmartPayPaymentStore.read()
        XCTAssertEqual(restored?.reference, "EW-QSGD99")
        XCTAssertEqual(restored?.email, "user@example.com")
        XCTAssertEqual(restored?.merchantOrderNo, "EW-QSGD99-1")
        XCTAssertNil(payment.toJson()["accessToken"])

        await PendingSmartPayPaymentStore.clear()
        XCTAssertNil(PendingSmartPayPaymentStore.read())
    }

    func testAHalfWrittenPendingRecordIsIgnoredRatherThanTrusted() {
        AppPrefs.setString("booking.pending_smartpay_payment", #"{"reference":"EW-QSGD99"}"#)

        XCTAssertNil(PendingSmartPayPaymentStore.read())
    }
}
