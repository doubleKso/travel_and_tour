import XCTest
@testable import EpicWorld

/// Ports the logic asserted by
/// test/features/home/presentation/pages/home_nationality_dropdown_test.dart
/// (a widget test): the search form opens on Myanmar, the dropdown offers
/// Myanmar and Other, a pick dispatches `nationalityChanged` to the shared
/// booking bloc, and dismissing the menu dispatches nothing.
@MainActor
final class HomeNationalityDropdownTests: XCTestCase {
    private func settle() async {
        for _ in 0..<20 { await Task.yield() }
    }

    func testTheSearchFormPicksANationalityFromItsDropdown() async {
        let container = AppContainer()
        let bloc = container.flightBookingBloc

        // Opens on Myanmar, with Other tucked away in the menu.
        XCTAssertEqual(bloc.state.nationality, .myanmar)
        XCTAssertEqual(bloc.state.nationality.label, "Myanmar")
        XCTAssertEqual(Nationality.values.map(\.label), ["Myanmar", "Other"])

        // Picking Other.
        bloc.add(.nationalityChanged(.foreigner))
        await settle()
        XCTAssertEqual(bloc.state.nationality, .foreigner)
        XCTAssertEqual(bloc.state.nationality.label, "Other")

        // Dismissing the menu without choosing adds no event, so the selection
        // stays as it was.
        await settle()
        XCTAssertEqual(bloc.state.nationality, .foreigner)

        // Picking Myanmar again.
        bloc.add(.nationalityChanged(.myanmar))
        await settle()
        XCTAssertEqual(bloc.state.nationality, .myanmar)
    }
}
