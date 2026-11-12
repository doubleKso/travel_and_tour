// Port of test/features/hotel/domain/entities/hotel_public_catalogue_test.dart
import XCTest
@testable import EpicWorld

final class HotelPublicCatalogueTests: XCTestCase {
    func testMapsAListActiveHotelsCatalogueItem() {
        let hotel = HotelModel.fromActiveApiJson([
            "id": "258977f7-419a-4c44-a05a-40669c38bdb9",
            "slug": "pan-pacific-yangon",
            "name": "Pan Pacific Yangon",
            "city": "Yangon",
            "country": "Myanmar",
            "flag": "mm",
            "starRating": 5,
            "imageUrl": "https://example.com/pan-pacific.jpg",
            "summary": NSNull(),
            "fromPrice": 267000,
            "featured": false,
            "amenities": "[\"Outdoor swimming pool\",\"Free Wifi\"]",
        ])

        XCTAssertEqual(hotel.slug, "pan-pacific-yangon")
        XCTAssertEqual(hotel.location, "Yangon, Myanmar")
        XCTAssertEqual(hotel.rating, 5)
        XCTAssertEqual(hotel.pricePerNight, 267000)
        XCTAssertEqual(hotel.amenities, ["Outdoor swimming pool", "Free Wifi"])
    }

    func testPutsFiveStarHotelsFirstWithoutChangingApiOrderWithinGroups() {
        func hotel(_ id: String, _ rating: Double) -> HotelModel {
            HotelModel(
                id: id,
                name: id,
                location: "",
                imageUrl: "",
                rating: rating,
                pricePerNight: 0,
                currency: "MMK"
            )
        }

        let ordered = fiveStarHotelsFirst([
            hotel("four-star-first", 4),
            hotel("five-star-first", 5),
            hotel("four-star-second", 4.5),
            hotel("five-star-second", 5),
        ])

        XCTAssertEqual(ordered.map(\.id), [
            "five-star-first",
            "five-star-second",
            "four-star-first",
            "four-star-second",
        ])
    }
}
