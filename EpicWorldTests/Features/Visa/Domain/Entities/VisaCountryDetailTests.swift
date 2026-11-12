// Port of test/features/visa/domain/entities/visa_country_detail_test.dart

import XCTest
@testable import EpicWorld

final class VisaCountryDetailTests: XCTestCase {
    // MARK: - GetVisaCountryBySlug

    func testMapsACountryProfile() {
        let country = VisaCountryDetail.fromJson([
            "id": "china-id",
            "slug": "china",
            "name": "China",
            "officialName": "People's Republic of China",
            "flagCode": "CN",
            "flagUrl": "https://example.com/cn.png",
            "emblemUrl": "https://example.com/cn-emblem.png",
            "globeUrl": "https://example.com/cn-globe.png",
            "intro": "China, officially the People\u{2019}s Republic of China…",
        ])

        XCTAssertEqual(country.id, "china-id")
        XCTAssertEqual(country.slug, "china")
        XCTAssertEqual(country.headline, "People's Republic of China")
        XCTAssertEqual(country.globeUrl, "https://example.com/cn-globe.png")
    }

    func testFallsBackToTheShortNameAndEmptyStrings() {
        let country = VisaCountryDetail.fromJson(["name": "Japan"])

        XCTAssertEqual(country.headline, "Japan")
        XCTAssertEqual(country.officialName, "")
        XCTAssertEqual(country.emblemUrl, "")
        XCTAssertEqual(country.intro, "")
    }

    // MARK: - GetVisaTypes

    func testMapsAVisaTypeWithAJsonArrayDocumentList() {
        let type = VisaTypeModel.fromJson([
            "code": "L",
            "title": "Tourist Visa (L)",
            "description": "A tourist visa allows you to visit for leisure.",
            "imageUrl": "https://example.com/tourist.jpg",
            "documents": #"["Passport","Citizenship Scrutiny Card (NRC)"]"#,
        ])

        XCTAssertEqual(type.headline, "Tourist Visa (L)")
        XCTAssertEqual(type.documents, ["Passport", "Citizenship Scrutiny Card (NRC)"])
    }

    func testTitlesFallBackToTheCode() {
        let type = VisaTypeModel.fromJson(["code": "l", "title": ""])

        XCTAssertEqual(type.headline, "L")
        XCTAssertTrue(type.documents.isEmpty)
    }

    // MARK: - parseVisaDocuments

    func testSplitsOneDocumentPerLineAndStripsListMarkers() {
        XCTAssertEqual(
            parseVisaDocuments("- Passport\n\u{2022} Photograph\n\n* NRC"),
            ["Passport", "Photograph", "NRC"]
        )
    }

    func testSplitsPipeAndSemicolonSeparatedValues() {
        XCTAssertEqual(parseVisaDocuments("Passport | Photograph"), ["Passport", "Photograph"])
        XCTAssertEqual(parseVisaDocuments("Passport; Photograph"), ["Passport", "Photograph"])
    }

    func testFallsBackToCommasPreferringStrongerSeparators() {
        XCTAssertEqual(
            parseVisaDocuments("Passport, NRC, Photograph"),
            ["Passport", "NRC", "Photograph"]
        )
        // A newline wins, so a comma inside a document name survives.
        XCTAssertEqual(
            parseVisaDocuments("Passport\nBank Book, Bank Statement"),
            ["Passport", "Bank Book, Bank Statement"]
        )
    }

    func testKeepsASingleUnseparatedDocumentAsOneEntry() {
        XCTAssertEqual(parseVisaDocuments("Passport"), ["Passport"])
    }

    func testAcceptsARealListAndIgnoresEmptyValues() {
        XCTAssertEqual(parseVisaDocuments(["Passport", "", "  NRC "]), ["Passport", "NRC"])
        XCTAssertTrue(parseVisaDocuments(nil).isEmpty)
        XCTAssertTrue(parseVisaDocuments("   ").isEmpty)
    }

    func testKeepsMalformedJsonAsPlainText() {
        XCTAssertEqual(parseVisaDocuments("[Passport"), ["[Passport"])
    }

    // MARK: - visa-free catalogue

    func testEveryEntryHasANameAndATwoLetterFlagCode() {
        XCTAssertFalse(visaFreeCountries.isEmpty)
        for country in visaFreeCountries {
            XCTAssertFalse(country.name.isEmpty)
            XCTAssertEqual(country.flagCode.count, 2, country.name)
            XCTAssertTrue(
                country.flagUrl.hasSuffix("\(country.flagCode.lowercased()).png"),
                country.flagUrl
            )
        }
    }
}
