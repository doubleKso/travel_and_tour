import XCTest
@testable import EpicWorld

/// Port of test/features/booking/domain/entities/flight_catalogue_response_test.dart.
final class FlightCatalogueResponseTests: XCTestCase {
    func testMapsAListActiveAirportsPlaceForTheFromToPicker() {
        let airport = AirportModel.fromJson([
            "code": "RGN",
            "city": "Yangon",
            "name": "Yangon International Airport",
            "country": "Myanmar",
            "searchCode": "YANGON",
        ])

        XCTAssertEqual(airport.code, "RGN")
        XCTAssertEqual(airport.cityName, "Yangon")
        XCTAssertEqual(airport.searchCode, "YANGON")
        XCTAssertTrue(airport.active)
    }

    func testMapsListActiveCountriesAndListActiveAirportCitiesItems() {
        let country = AirportCountryModel.fromJson([
            "code": "MM",
            "name": "Myanmar",
            "logoUrl": "https://example.com/mm.png",
        ])
        let city = AirportCityModel.fromJson([
            "code": "RGN",
            "name": "Yangon",
            "country": "Myanmar",
            "isDomestic": true,
            "isInternational": true,
        ])

        XCTAssertEqual(country.name, "Myanmar")
        XCTAssertEqual(country.logoUrl, "https://example.com/mm.png")
        XCTAssertEqual(city.code, "RGN")
        XCTAssertTrue(city.isDomestic)
        XCTAssertTrue(city.isInternational)
    }

    func testFiltersAirportCitiesByTheDomesticOrInternationalAvailability() {
        let domesticOnly = AirportCityModel.fromJson([
            "code": "VBA",
            "name": "ANN",
            "country": "Myanmar",
            "isDomestic": true,
            "isInternational": false,
        ])
        let internationalOnly = AirportCityModel.fromJson([
            "code": "BKK",
            "name": "Bangkok",
            "country": "Thailand",
            "isDomestic": false,
            "isInternational": true,
        ])

        XCTAssertTrue(domesticOnly.isAvailableFor(domestic: true))
        XCTAssertFalse(domesticOnly.isAvailableFor(domestic: false))
        XCTAssertFalse(internationalOnly.isAvailableFor(domestic: true))
        XCTAssertTrue(internationalOnly.isAvailableFor(domestic: false))
    }

    func testMapsListActiveCarriersAndListActiveFlightSchedulesItems() {
        let carrier = FlightCarrierModel.fromJson([
            "code": "8M",
            "name": "MAI Airway",
            "logoUrl": "https://example.com/8m.png",
            "bookable": true,
        ])
        let schedule = FlightScheduleModel.fromJson([
            "airlineCode": "8M",
            "airlineName": "MAI Airway",
            "flightNo": "8M-231",
            "fromCode": "RGN",
            "fromCity": "Yangon",
            "toCode": "BKK",
            "toCity": "Bangkok",
            "departTime": "08:30",
            "arriveTime": "10:20",
            "arrivesNextDay": false,
            "daysOfWeek": "Daily",
            "stops": 0,
            "indicativeFare": 125000,
            "currency": "MMK",
            "effectiveFrom": "2026-08-20",
            "effectiveTo": "2026-12-31",
        ])

        XCTAssertTrue(carrier.bookable)
        XCTAssertEqual(schedule.flightNo, "8M-231")
        XCTAssertEqual(schedule.airlineAndFlightLabel, "MAI Airway, 8M-231")
        XCTAssertEqual(schedule.indicativeFare, 125000)
        XCTAssertFalse(schedule.arrivesNextDay)
    }

    func testTurnsMatchingNonMaiSchedulesIntoEnquiryOnlyTripOptions() {
        let schedule = FlightScheduleModel.fromJson([
            "airlineCode": "MNA",
            "airlineName": "Myanmar National Airlines",
            "flightNo": "",
            "fromCode": "RGN",
            "fromCity": "Yangon",
            "toCode": "MDL",
            "toCity": "Mandalay",
            "departTime": "11:00",
            "arriveTime": "12:00",
            "arrivesNextDay": false,
            "daysOfWeek": "daily",
            "stops": 0,
            "indicativeFare": 300000,
            "currency": "MMK",
            "effectiveFrom": NSNull(),
            "effectiveTo": NSNull(),
        ])
        let date = DateTime(2026, 8, 30)

        XCTAssertTrue(schedule.operatesOn(from: "RGN", to: "MDL", date: date))
        XCTAssertFalse(schedule.operatesOn(from: "RGN", to: "BKK", date: date))

        let option = schedule.toTripOption(date)
        XCTAssertEqual(schedule.airlineAndFlightLabel, "Myanmar National Airlines")
        XCTAssertEqual(option.operatorName, "Myanmar National Airlines")
        XCTAssertEqual(option.departure.hour, 11)
        XCTAssertEqual(option.arrival.hour, 12)
        XCTAssertEqual(option.price, 300000)
        XCTAssertEqual(option.bookable, false)
    }

    func testFindsTheNextScheduledDateForACommercialFlightEnquiry() {
        let schedule = FlightScheduleModel.fromJson([
            "airlineCode": "MNA",
            "airlineName": "Myanmar National Airlines",
            "fromCode": "RGN",
            "fromCity": "Yangon",
            "toCode": "MDL",
            "toCity": "Mandalay",
            "departTime": "11:00",
            "arriveTime": "12:00",
            "daysOfWeek": "mon",
            "stops": 0,
            "indicativeFare": 300000,
            "currency": "MMK",
        ])

        let date = schedule.nextOperatingDate(DateTime(2026, 9, 15))

        XCTAssertEqual(date.weekday, 1) // DateTime.monday
        XCTAssertEqual(date, DateTime(2026, 9, 21))
    }

    func testMapsGlobalAndTierSpecificAirlineRatesAndBenefits() {
        let globalRate = GlobalAirlineRateModel.fromJson([
            "carrierCode": "8M",
            "ratePct": 3.5,
        ])
        let tierRate = TierAirlineRateModel.fromJson([
            "tierId": "gold",
            "carrierCode": "8M",
            "ratePct": 5,
        ])
        let benefit = TierBenefitModel.fromJson([
            "tierId": "gold",
            "service": "flights",
            "discountPct": 10,
        ])

        XCTAssertEqual(globalRate.ratePct, 3.5)
        XCTAssertEqual(tierRate.tierId, "gold")
        XCTAssertEqual(tierRate.ratePct, 5)
        XCTAssertEqual(benefit.service, "flights")
        XCTAssertEqual(benefit.discountPct, 10)
    }
}
