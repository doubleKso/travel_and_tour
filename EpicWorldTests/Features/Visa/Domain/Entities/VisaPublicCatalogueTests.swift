// Port of test/features/visa/domain/entities/visa_public_catalogue_test.dart

import XCTest
@testable import EpicWorld

final class VisaPublicCatalogueTests: XCTestCase {
    func testMapsActiveVisaCountriesFromDcExec() {
        let country = VisaCountryModel.fromJson([
            "id": "thailand",
            "slug": "thailand",
            "name": "Thailand",
            "flagCode": "TH",
            "flagUrl": "https://example.com/th.png",
            "featured": true,
        ])

        XCTAssertEqual(country.id, "thailand")
        XCTAssertEqual(country.name, "Thailand")
        XCTAssertEqual(country.flagCode, "TH")
        XCTAssertTrue(country.featured)
    }

    func testMapsPublishedVisaTypeCountryIdsFromDcExec() {
        let type = VisaTypeCountryModel.fromJson(["countryId": "thailand"])

        XCTAssertEqual(type.countryId, "thailand")
    }

    func testShowsOnlyActiveCountriesWithAPublishedVisaType() {
        let thailand = VisaCountryModel(
            id: "Thailand-ID",
            slug: "thailand",
            name: "Thailand",
            flagCode: "TH",
            flagUrl: "",
            featured: true
        )
        let japan = VisaCountryModel(
            id: "japan-id",
            slug: "japan",
            name: "Japan",
            flagCode: "JP",
            flagUrl: "",
            featured: false
        )

        let visible = publishedVisaCountries(
            [thailand, japan],
            [VisaTypeCountryModel(countryId: " thailand-id ")]
        )

        // Dart compares the (identical) const instance; the models have no
        // value equality, so compare by identity fields.
        XCTAssertEqual(visible.map(\.id), [thailand.id])
        XCTAssertEqual(visible.map(\.slug), [thailand.slug])
    }
}
