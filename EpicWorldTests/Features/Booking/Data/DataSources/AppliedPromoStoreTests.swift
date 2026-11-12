import XCTest
@testable import EpicWorld

/// Port of test/features/booking/data/datasources/applied_promo_store_test.dart.
final class AppliedPromoStoreTests: XCTestCase {
    private static let suiteName = "EpicWorldTests.AppliedPromoStore"
    private var previousStore: UserDefaults!

    private let promo = PromoCodeCheckResponse(
        ok: true,
        code: "EPIC10",
        amount: 12500,
        kind: "percent",
        value: 10,
        minSpend: 50000,
        reason: "",
        message: "Promo applied"
    )

    override func setUp() {
        super.setUp()
        previousStore = AppPrefs.store
        prefs()
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: Self.suiteName)
        AppPrefs.store = previousStore
        super.tearDown()
    }

    /// `SharedPreferences.setMockInitialValues(initial)` + `AppPrefs.init()`.
    private func prefs(_ initial: [String: String] = [:]) {
        UserDefaults().removePersistentDomain(forName: Self.suiteName)
        AppPrefs.store = UserDefaults(suiteName: Self.suiteName)!
        for (key, value) in initial { AppPrefs.setString(key, value) }
    }

    func testAnAppliedPromoSurvivesAReloadOfTheSameBooking() async {
        await AppliedPromoStore.save(
            AppliedPromo(reference: "EW-QSGD99", code: "EPIC10", discount: 12500, promo: promo)
        )

        let restored = AppliedPromoStore.read("EW-QSGD99")
        XCTAssertEqual(restored?.code, "EPIC10")
        XCTAssertEqual(restored?.discount, 12500)
        // The badge the screen draws ("10% off") comes back intact.
        XCTAssertEqual(restored?.promo.kind, "percent")
        XCTAssertEqual(restored?.promo.value, 10)
        XCTAssertEqual(restored?.promo.ok, true)
    }

    func testAPromoDoesNotFollowTheCustomerOntoAnotherBooking() async {
        await AppliedPromoStore.save(
            AppliedPromo(reference: "EW-QSGD99", code: "EPIC10", discount: 12500, promo: promo)
        )

        XCTAssertNil(AppliedPromoStore.read("EW-OTHER1"))
        XCTAssertNil(AppliedPromoStore.read(""))
    }

    func testRemovingThePromoRemovesItFromStorageToo() async {
        await AppliedPromoStore.save(
            AppliedPromo(reference: "EW-QSGD99", code: "EPIC10", discount: 12500, promo: promo)
        )

        await AppliedPromoStore.clear()

        XCTAssertNil(AppliedPromoStore.read("EW-QSGD99"))
    }

    func testARecordTheBackendNeverApprovedIsNotRestored() {
        prefs([
            "booking.applied_promo": #"{"reference":"EW-QSGD99","code":"EPIC10","discount":12500,"promo":{"ok":false,"code":"EPIC10"}}"#,
        ])

        XCTAssertNil(AppliedPromoStore.read("EW-QSGD99"))
    }

    func testADamagedRecordIsIgnoredRatherThanTrusted() {
        for value in [
            "not json at all",
            "[]",
            #"{"reference":"EW-QSGD99"}"#,
        ] {
            prefs(["booking.applied_promo": value])
            XCTAssertNil(AppliedPromoStore.read("EW-QSGD99"), "expected \"\(value)\" to be discarded")
        }
    }

    func testAPromoResponseRoundTripsThroughJsonUnchanged() {
        let restored = PromoCodeCheckResponse.fromJson(promo.toJson())

        XCTAssertEqual(restored.ok, promo.ok)
        XCTAssertEqual(restored.code, promo.code)
        XCTAssertEqual(restored.amount, promo.amount)
        XCTAssertEqual(restored.kind, promo.kind)
        XCTAssertEqual(restored.value, promo.value)
        XCTAssertEqual(restored.minSpend, promo.minSpend)
        XCTAssertEqual(restored.message, promo.message)
    }
}
