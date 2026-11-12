import XCTest
@testable import EpicWorld

/// Port of test/features/booking/domain/entities/flight_search_response_test.dart.
final class FlightSearchResponseTests: XCTestCase {
    private func json(_ text: String) throws -> JSON {
        try XCTUnwrap(Dart.map(try jsonDecode(text)))
    }

    func testMapsCallableResultOptionsIntoResultCardTripOptions() throws {
        let response = FlightSearchResponse.fromJson(try json(#"""
        {
          "result": {
            "live": true,
            "notice": null,
            "options": [
              {
                "id": "mai-8M204-2026-08-20-0",
                "carrier": {
                  "id": "8M",
                  "name": "MYANMAR AIRWAYS",
                  "logo": "https://pics.avs.io/200/200/8M.png",
                  "type": "flight"
                },
                "mode": "flight",
                "flightNo": "8M204",
                "from": {"code": "RGN", "city": "Yangon MINGALADON"},
                "to": {"code": "MDL", "city": "MANDALAY"},
                "date": "2026-08-20",
                "departTime": "07:00 AM",
                "arriveTime": "08:35 AM",
                "arriveDayOffset": 0,
                "stops": 0,
                "cabin": "ECONOMY",
                "price": 375435,
                "totalPrice": 375435,
                "currency": "MMK",
                "seatsLeft": 9,
                "refundable": false,
                "bookable": true,
                "bookingClass": "M",
                "aircraft": "ATR72-212A",
                "departTerminal": "3",
                "arriveTerminal": null,
                "amenities": [],
                "fareBrand": "ECO SAVER",
                "fareBasis": "MOW6MFRN",
                "fares": [
                  {"selected": true, "baggageKg": 20}
                ],
                "segments": [
                  {
                    "flightNumber": "8M204",
                    "departAt": "2026-08-20T07:00:00+06:30",
                    "arriveAt": "2026-08-20T08:35:00+06:30"
                  }
                ]
              }
            ]
          }
        }
        """#))

        XCTAssertTrue(response.live)
        XCTAssertEqual(response.options.count, 1)
        let option = try XCTUnwrap(response.options.first)
        XCTAssertEqual(option.id, "mai-8M204-2026-08-20-0")
        XCTAssertEqual(option.operatorName, "MYANMAR AIRWAYS")
        XCTAssertEqual(option.carrierCode, "8M")
        XCTAssertEqual(option.operatorLogoUrl, "https://pics.avs.io/200/200/8M.png")
        XCTAssertEqual(option.originCode, "RGN")
        XCTAssertEqual(option.destinationCode, "MDL")
        XCTAssertEqual(option.departure.hour, 7)
        XCTAssertEqual(option.arrival.hour, 8)
        XCTAssertEqual(option.price, 375435)
        XCTAssertEqual(option.currency, "MMK")
        XCTAssertEqual(option.travelClass, .economy)
        XCTAssertEqual(option.flightNumber, "8M204")
        XCTAssertEqual(option.baggageKg, 20)
        XCTAssertEqual(option.fareBasis, "MOW6MFRN")
        XCTAssertEqual(option.bookable, true)
        XCTAssertEqual(option.bookingClass, "M")
        XCTAssertEqual(option.aircraft, "ATR72-212A")
        XCTAssertEqual(option.departureTerminal, "3")
    }

    func testIncludesEnquiryOnlyAirlineResultsAndPreservesMaiFareOptions() throws {
        let response = FlightSearchResponse.fromJson(try json(#"""
        {
          "result": {
            "options": [
              {
                "id": "mai-8M204",
                "carrier": {"code": "8M", "name": "MYANMAR AIRWAYS"},
                "from": {"code": "RGN", "city": "Yangon"},
                "to": {"code": "MDL", "city": "Mandalay"},
                "date": "2026-08-20",
                "departTime": "07:00 AM",
                "arriveTime": "08:35 AM",
                "currency": "MMK",
                "totalPrice": 359397,
                "fares": [
                  {
                    "fareBrand": "ECO SAVER",
                    "fareBasis": "MOW6MFRN",
                    "cabin": "ECONOMY",
                    "price": 359397,
                    "currency": "MMK",
                    "baggageKg": 20,
                    "selected": true
                  },
                  {
                    "fareBrand": "ECO FLEXI",
                    "fareBasis": "YOW6MFRN",
                    "cabin": "ECONOMY",
                    "price": 412641,
                    "currency": "MMK",
                    "baggageKg": 20
                  }
                ]
              }
            ],
            "otherAirlines": [
              {
                "id": "mna-ub101",
                "carrier": {"code": "UB", "name": "Myanmar National Airlines"},
                "from": {"code": "RGN", "city": "Yangon"},
                "to": {"code": "MDL", "city": "Mandalay"},
                "date": "2026-08-20",
                "departTime": "11:00 AM",
                "arriveTime": "12:00 PM",
                "indicativeFare": 300000,
                "currency": "MMK"
              }
            ]
          }
        }
        """#))

        XCTAssertEqual(response.options.count, 2)
        let mai = try XCTUnwrap(response.options.first)
        XCTAssertEqual(mai.fareOptions.count, 2)
        let flexi = try XCTUnwrap(mai.fareOptions.last)
        XCTAssertEqual(flexi.brand, "ECO FLEXI")
        XCTAssertEqual(mai.withFare(flexi).price, 412641)
        XCTAssertEqual(mai.withFare(flexi).fareBasis, "YOW6MFRN")

        let mna = try XCTUnwrap(response.options.last)
        XCTAssertEqual(mna.operatorName, "Myanmar National Airlines")
        XCTAssertEqual(mna.carrierCode, "UB")
        XCTAssertEqual(mna.price, 300000)
        XCTAssertTrue(mna.fareOptions.isEmpty)
    }

    func testMapsABusinessCabinResponseOntoTravelClassBusiness() throws {
        // Trimmed from a real searchFlights response for a business search.
        let response = FlightSearchResponse.fromJson(try json(#"""
        {
          "result": {
            "live": true,
            "notice": null,
            "options": [
              {
                "id": "mai-8M335-2026-09-02-0",
                "carrier": {
                  "id": "8M",
                  "name": "MYANMAR AIRWAYS",
                  "logo": "https://pics.avs.io/200/200/8M.png",
                  "type": "flight"
                },
                "mode": "flight",
                "flightNo": "8M335",
                "from": {"code": "RGN", "city": "Yangon MINGALADON"},
                "to": {"code": "BKK", "city": "Bangkok"},
                "date": "2026-09-02",
                "departTime": "07:25 AM",
                "arriveTime": "09:15 AM",
                "arriveDayOffset": 0,
                "stops": 0,
                "cabin": "BUSINESS",
                "bookingClass": "D",
                "price": 1326663,
                "currency": "MMK",
                "totalPrice": 1326663,
                "seatsLeft": 2,
                "bookable": true,
                "source": "mai",
                "fareBrand": "IBIZ PROMO",
                "fares": [
                  {
                    "brand": "IBIZ PROMO",
                    "cabin": "BUSINESS",
                    "bookingClass": "D",
                    "price": 1326663,
                    "totalPrice": 1326663,
                    "currency": "MMK",
                    "baggageKg": 30,
                    "seatsLeft": 2,
                    "selected": true
                  }
                ]
              }
            ]
          }
        }
        """#))

        let option = try XCTUnwrap(response.options.first)
        XCTAssertEqual(response.options.count, 1)
        XCTAssertEqual(option.travelClass, .business)
        XCTAssertEqual(option.price, 1326663)
        XCTAssertEqual(option.operatorName, "MYANMAR AIRWAYS")
        XCTAssertEqual(option.originCode, "RGN")
        XCTAssertEqual(option.destinationCode, "BKK")
    }

    func testAcceptsCatalogueLogoUrlAirlineCodeAndStringStopCounts() throws {
        let response = FlightSearchResponse.fromJson(try json(#"""
        {
          "flights": [
            {
              "id": "mna-ub101",
              "carrier": {"name": "", "code": "", "logo": ""},
              "airlineName": "Myanmar National Airlines",
              "airlineCode": "UB",
              "logoUrl": "https://example.com/ub.png",
              "fromCode": "RGN",
              "toCode": "BKK",
              "date": "2026-09-10",
              "departTime": "08:00",
              "arriveTime": "11:00",
              "stops": "1",
              "price": 300000
            }
          ]
        }
        """#))

        let option = try XCTUnwrap(response.options.first)
        XCTAssertEqual(response.options.count, 1)
        XCTAssertEqual(option.carrierCode, "UB")
        XCTAssertEqual(option.operatorLogoUrl, "https://example.com/ub.png")
        XCTAssertEqual(option.stops, 1)
    }

    func testKeepsThePerPassengerFareAlongsideThePartyTotal() throws {
        let response = FlightSearchResponse.fromJson(try json(#"""
        {
          "result": {
            "options": [
              {
                "id": "mai-8M204-2026-10-30-0",
                "carrier": {"id": "MAI", "iata": "8M", "name": "MYANMAR AIRWAYS"},
                "flightNo": "8M204",
                "from": {"code": "RGN"},
                "to": {"code": "MDL"},
                "date": "2026-10-30",
                "departTime": "07:00 AM",
                "arriveTime": "08:35 AM",
                "price": 359397,
                "totalPrice": 718794,
                "paxCount": 2,
                "currency": "MMK",
                "fareBasis": "MOW6MFRN",
                "fares": [
                  {
                    "brand": "ECO SAVER",
                    "fareBasis": "MOW6MFRN",
                    "price": 359397,
                    "totalPrice": 718794,
                    "selected": true
                  },
                  {
                    "brand": "ECO FLEXI",
                    "fareBasis": "OOWFRN",
                    "price": 412641,
                    "totalPrice": 825282
                  }
                ]
              }
            ]
          }
        }
        """#))

        let option = try XCTUnwrap(response.options.first)
        XCTAssertEqual(response.options.count, 1)
        XCTAssertEqual(option.price, 718794)
        XCTAssertEqual(option.pricePerPax, 359397)

        let flexi = option.withFare(try XCTUnwrap(option.fareOptions.last))
        XCTAssertEqual(flexi.price, 825282)
        XCTAssertEqual(flexi.pricePerPax, 412641)
    }
}
