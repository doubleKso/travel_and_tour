import XCTest
@testable import EpicWorld

/// Port of test/features/booking/data/datasources/guest_booking_store_test.dart.
///
/// `FlutterSecureStorage.setMockInitialValues` becomes a test-only Keychain
/// service, emptied before every test.
final class GuestBookingStoreTests: XCTestCase {
    private var previousStorage: KeychainStore!

    override func setUp() async throws {
        try await super.setUp()
        previousStorage = GuestBookingStore.storage
        GuestBookingStore.storage = KeychainStore(service: "EpicWorldTests.guest_bookings")
        await GuestBookingStore.clear()
    }

    override func tearDown() async throws {
        await GuestBookingStore.clear()
        GuestBookingStore.storage = previousStorage
        try await super.tearDown()
    }

    private func record(
        _ reference: String,
        email: String = "guest@gmail.com",
        status: String = GuestBookingStatus.pendingPayment,
        amount: Double = 100
    ) -> GuestBookingRecord {
        GuestBookingRecord(
            reference: reference,
            email: email,
            route: "RGN → BKK",
            service: "flight",
            travelDate: "2026-09-06",
            savedAt: DateTime.now(),
            ticketTimeLimit: DateTime.now().add(Duration(hours: 6)),
            amount: amount,
            currency: "MMK",
            status: status
        )
    }

    func testNothingStoredReadsAsNoBookings() async {
        let stored = await GuestBookingStore.read()
        XCTAssertTrue(stored.isEmpty)
    }

    func testANewBookingGoesToTheFrontNewestFirst() async {
        await GuestBookingStore.save(record("EW-1"))
        await GuestBookingStore.save(record("EW-2"))

        let stored = await GuestBookingStore.read()
        XCTAssertEqual(stored.map(\.reference), ["EW-2", "EW-1"])
    }

    func testReSavingAKnownBookingRefreshesItWithoutMovingIt() async {
        await GuestBookingStore.save(record("EW-1"))
        await GuestBookingStore.save(record("EW-2"))
        await GuestBookingStore.save(record("EW-1", amount: 999))

        let stored = await GuestBookingStore.read()
        XCTAssertEqual(stored.map(\.reference), ["EW-2", "EW-1"], "a refresh must not shuffle the cards around it")
        XCTAssertEqual(stored.last?.amount, 999)
    }

    func testPayingABookingFlipsOnlyThatRow() async {
        await GuestBookingStore.save(record("EW-1"))
        await GuestBookingStore.save(record("EW-2"))

        await GuestBookingStore.updateStatus("EW-1", GuestBookingStatus.confirmed)

        let stored = await GuestBookingStore.read()
        XCTAssertEqual(stored.first { $0.reference == "EW-1" }?.status, GuestBookingStatus.confirmed)
        XCTAssertEqual(stored.first { $0.reference == "EW-2" }?.status, GuestBookingStatus.pendingPayment)
    }

    func testABookingCanBeForgottenAndTheListCleared() async {
        await GuestBookingStore.save(record("EW-1"))
        await GuestBookingStore.save(record("EW-2"))

        await GuestBookingStore.remove("EW-1")
        let remaining = await GuestBookingStore.read()
        XCTAssertEqual(remaining.map(\.reference), ["EW-2"])

        await GuestBookingStore.clear()
        let cleared = await GuestBookingStore.read()
        XCTAssertTrue(cleared.isEmpty)
    }

    func testTheListIsCappedSoASharedDeviceCannotGrowOne() async {
        for i in 0..<14 {
            await GuestBookingStore.save(record("EW-\(i)"))
        }

        let stored = await GuestBookingStore.read()
        XCTAssertEqual(stored.count, 10)
        XCTAssertEqual(stored.first?.reference, "EW-13", "newest survives")
        XCTAssertEqual(stored.last?.reference, "EW-4")
    }

    func testABookingWithNoReferenceOrEmailIsNotWorthStoring() async {
        await GuestBookingStore.save(record(""))
        await GuestBookingStore.save(record("EW-9", email: ""))

        let stored = await GuestBookingStore.read()
        XCTAssertTrue(stored.isEmpty)
    }

    func testADamagedPayloadReadsAsEmptyRatherThanThrowing() async {
        GuestBookingStore.storage.write("booking.guest_bookings", "not json at all")
        let garbage = await GuestBookingStore.read()
        XCTAssertTrue(garbage.isEmpty)

        GuestBookingStore.storage.write("booking.guest_bookings", #"{"reference":"EW-1"}"#)
        let object = await GuestBookingStore.read()
        XCTAssertTrue(object.isEmpty, "an object where a list belongs is a leftover, not a booking")
    }
}
