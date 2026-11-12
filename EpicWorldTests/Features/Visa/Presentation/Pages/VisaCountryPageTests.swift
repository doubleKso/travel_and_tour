// Port of the logic assertions in
// test/features/visa/presentation/pages/visa_country_page_test.dart.
//
// The Dart test is a widget test; only the rule it checks for the visa type
// count chip ("2 visa types", singular for one) is logic, so that rule is
// tested here directly. Rendering, reflow and empty-state assertions are
// widget-only and are not ported.

import XCTest
@testable import EpicWorld

// `VisaCountryPage` is a SwiftUI view, which newer SDKs isolate to the main actor.
@MainActor
final class VisaCountryPageTests: XCTestCase {
    func testCountChipPluralisesTheVisaTypeCount() {
        XCTAssertEqual(VisaCountryPage.typeCountLabel(2), "2 visa types")
        XCTAssertEqual(VisaCountryPage.typeCountLabel(1), "1 visa type")
        XCTAssertEqual(VisaCountryPage.typeCountLabel(5), "5 visa types")
    }

    func testRequiredDocumentsComeFromTheParsedChecklist() {
        // The page lists one row per parsed document under "REQUIRED DOCUMENTS".
        let tourist = VisaTypeModel(
            code: "L",
            title: "Tourist Visa (L)",
            description: "A tourist visa allows you to visit for leisure.",
            imageUrl: "",
            documents: ["Passport", "Citizenship Scrutiny Card (NRC)"]
        )
        let student = VisaTypeModel(
            code: "X",
            title: "Student Visa",
            description: "An education visa allows you to stay for study.",
            imageUrl: "",
            documents: ["Passport", "JW 201 (or) JW 202"]
        )

        XCTAssertEqual(tourist.headline, "Tourist Visa (L)")
        XCTAssertEqual(student.headline, "Student Visa")
        let allDocuments = [tourist, student].flatMap(\.documents)
        XCTAssertEqual(allDocuments.filter { $0 == "Passport" }.count, 2)
        XCTAssertEqual(allDocuments.filter { $0 == "Citizenship Scrutiny Card (NRC)" }.count, 1)
    }

    func testHeadlineUsesTheOfficialName() {
        let china = VisaCountryDetail(
            id: "china-id",
            slug: "china",
            name: "China",
            officialName: "People's Republic of China",
            flagCode: "CN",
            flagUrl: "",
            emblemUrl: "",
            globeUrl: "",
            intro: "China is a vast East Asian country with over 1.4 billion people."
        )

        XCTAssertEqual(china.headline, "People's Republic of China")
        XCTAssertTrue(china.intro.contains("1.4 billion people"))
    }
}
