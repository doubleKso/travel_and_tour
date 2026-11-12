// Port of test/features/tour/domain/entities/tour_public_catalogue_test.dart

import XCTest
@testable import EpicWorld

final class TourPublicCatalogueTests: XCTestCase {
    func testMapsAListActiveTourPackagesSummary() {
        let tour = TourPackage.fromActiveApiJson([
            "id": "tour-1",
            "slug": "thailand-discovery",
            "name": "Thailand Discovery",
            "duration": "4 Nights / 5 Days",
            "days": 5,
            "country": "Thailand",
            "flag": "TH",
            "route": "Bangkok — Phuket",
            "imageUrl": "https://example.com/thailand.jpg",
            "summary": "A guided Thailand getaway.",
            "fromPrice": 550000,
            "featured": true,
        ])

        XCTAssertEqual(tour.id, "tour-1")
        XCTAssertEqual(tour.title, "Thailand Discovery")
        XCTAssertEqual(tour.priceFrom, 550000)
        XCTAssertEqual(tour.overview, "A guided Thailand getaway.")
    }
}
