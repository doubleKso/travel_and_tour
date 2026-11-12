import XCTest
@testable import EpicWorld

/// Logic assertions from
/// test/features/booking/presentation/pages/flight_search_loading_test.dart
/// (the widget test itself is not ported): the status line rotates with the
/// 3 s timeline.
final class FlightSearchLoadingTests: XCTestCase {
    @MainActor
    func testTheStatusLineStartsOnSearching() {
        // `tester.pump(500ms)` → timeline value 500 / 3000.
        let index = FlightSearchLoadingPage.statusIndex(at: 500.0 / 3000.0)
        XCTAssertEqual(FlightSearchLoadingPage.statuses[index], "Searching for flights…")
    }

    @MainActor
    func testTheStatusLineRotatesPastTheMidpoint() {
        // A further `pump(1000ms)` → 1500 / 3000: the plane has crossed the globe.
        let index = FlightSearchLoadingPage.statusIndex(at: 1500.0 / 3000.0)
        XCTAssertEqual(FlightSearchLoadingPage.statuses[index], "Finding the best routes…")
    }

    @MainActor
    func testTheStatusIndexStaysInRange() {
        XCTAssertEqual(FlightSearchLoadingPage.statusIndex(at: 0), 0)
        XCTAssertEqual(FlightSearchLoadingPage.statusIndex(at: 1), FlightSearchLoadingPage.statuses.count - 1)
    }

    @MainActor
    func testTheRouteChipShowsBothDefaultCodes() {
        // `find.text(from.code)` / `find.text(to.code)` with the default route.
        XCTAssertEqual(LocationModel.defaultOrigin.code, "RGN")
        XCTAssertEqual(LocationModel.defaultDestination.code, "MDL")
    }
}
