import XCTest
@testable import EpicWorld

/// Port of test/features/booking/domain/entities/flight_hold_models_test.dart.
final class FlightHoldModelsTests: XCTestCase {
    private let flight = TripOptionModel(
        id: "option-1",
        mode: .flight,
        operatorName: "MAI Airway",
        operatorLogoUrl: "",
        originCode: "RGN",
        originName: "Yangon",
        destinationCode: "MDL",
        destinationName: "Mandalay",
        departure: DateTime(2026, 8, 25, 7),
        arrival: DateTime(2026, 8, 25, 8, 20),
        stops: 0,
        travelClass: .economy,
        price: 375435,
        currency: "MMK",
        flightNumber: "8M204",
        fareBrand: "MOW6MFRN",
        fareBasis: "MOW6MFRN"
    )

    func testMapsTheHoldFlightSelectionAndCallablePayload() {
        let request = FlightHoldRequest(
            selections: [FlightHoldRequest.selectionFrom(flight)],
            passengers: [],
            contact: [:]
        )
        let payload = request.toJson(accessToken: "access-token")

        XCTAssertEqual(Dart.str(payload["accessToken"]), "access-token")
        XCTAssertEqual(Dart.bool(payload["acceptPriceChange"]), false)
        let selections = Dart.maps(payload["selections"])
        XCTAssertEqual(selections.count, 1)
        XCTAssertEqual(
            NSDictionary(dictionary: selections[0]),
            NSDictionary(dictionary: [
                "from": "RGN",
                "to": "MDL",
                "departDate": "2026-08-25",
                "departAt": "2026-08-25T07:00:00+06:30",
                "flightNo": "8M204",
                "expectedPrice": 375435,
                "fareBasis": "MOW6MFRN",
            ])
        )
    }

    func testExpectsThePerPassengerFareNotThePartyTotal() {
        // Live `searchFlights` result for 2 adults: `price` is per passenger and
        // `totalPrice` covers both. Sending the total was rejected as a fare
        // change.
        let twoAdults = TripOptionModel(
            id: "mai-8M204-2026-10-30-0",
            mode: .flight,
            operatorName: "MYANMAR AIRWAYS",
            operatorLogoUrl: "",
            originCode: "RGN",
            originName: "Yangon",
            destinationCode: "MDL",
            destinationName: "Mandalay",
            departure: DateTime(2026, 10, 30, 7),
            arrival: DateTime(2026, 10, 30, 8, 35),
            stops: 0,
            travelClass: .economy,
            price: 718794,
            pricePerPax: 359397,
            currency: "MMK",
            flightNumber: "8M204",
            fareBasis: "MOW6MFRN"
        )

        XCTAssertEqual(Dart.int(FlightHoldRequest.selectionFrom(twoAdults)["expectedPrice"]), 359397)
    }

    func testSendsAV4UuidRequestKeyFixedForTheLifeOfTheRequest() throws {
        let request = FlightHoldRequest(
            selections: [FlightHoldRequest.selectionFrom(flight)],
            passengers: [],
            contact: [:]
        )
        let key = try XCTUnwrap(Dart.str(request.toJson()["requestKey"]))

        XCTAssertNotNil(
            key.range(
                of: #"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"#,
                options: .regularExpression
            )
        )
        XCTAssertEqual(Dart.str(request.toJson(accessToken: "retry-token")["requestKey"]), key)
        XCTAssertNotEqual(
            FlightHoldRequest(selections: [], passengers: [], contact: [:]).requestKey,
            key
        )
    }

    func testKeepsASuppliedRequestKey() {
        let request = FlightHoldRequest(
            requestKey: "7f3c1e62-0f1a-4f3e-9a1b-2c4d5e6f7a8b",
            selections: [],
            passengers: [],
            contact: [:]
        )

        XCTAssertEqual(Dart.str(request.toJson()["requestKey"]), "7f3c1e62-0f1a-4f3e-9a1b-2c4d5e6f7a8b")
    }

    func testAllowsAGuestHoldRequestWithoutAnAccessToken() {
        let request = FlightHoldRequest(
            selections: [FlightHoldRequest.selectionFrom(flight)],
            passengers: [],
            contact: [:]
        )

        XCTAssertTrue(Dart.isNull(request.toJson()["accessToken"]))
    }

    func testMapsTheHoldFlightResponse() throws {
        let response = FlightHoldResponse.fromJson(try json(#"""
        {
          "ok": true,
          "bookingId": "booking-1",
          "reference": "EW-V92BJV",
          "pnr": "17RB12",
          "pnrStatus": null,
          "ticketTimeLimit": "2026-08-20T15:27:14.000Z",
          "ticketTimeLimitLocal": "2026-08-20T21:57:14+06:30",
          "perPax": 399500,
          "total": 399500,
          "currency": "MMK",
          "passengers": 1,
          "legs": [
            {
              "flightNo": "8M331",
              "from": "RGN",
              "to": "BKK",
              "date": "2026-08-25",
              "departTime": "12:50 PM",
              "arriveTime": "02:40 PM",
              "price": 399500,
              "refundable": false,
              "baggageKg": 30,
              "fareBrand": "IECO SPECIAL",
              "rules": ["Non-refundable", "Change fee: 300000 MMK"]
            }
          ]
        }
        """#))

        XCTAssertTrue(response.ok)
        XCTAssertEqual(response.reference, "EW-V92BJV")
        XCTAssertEqual(response.pnr, "17RB12")
        XCTAssertNil(response.pnrStatus)
        XCTAssertEqual(response.total, 399500)
        XCTAssertEqual(response.ticketTimeLimitLocal, "2026-08-20T21:57:14+06:30")
        XCTAssertEqual(response.perPax, 399500)
        XCTAssertEqual(response.passengers, 1)
        XCTAssertEqual(response.legs.count, 1)
        XCTAssertEqual(response.legs.first?.flightNo, "8M331")
        XCTAssertEqual(response.legs.first?.baggageKg, 30)
        XCTAssertEqual(response.legs.first?.rules, ["Non-refundable", "Change fee: 300000 MMK"])
    }

    func testKeepsEnteredMaiFormDataInTheCallablePayload() {
        let passenger: JSON = [
            "title": "Mr",
            "firstName": "Aung",
            "lastName": "Aung",
            "type": "adult",
            "gender": "male",
            "dob": "1990-01-01",
            "nationality": "Myanmar",
            "nrc": "12/ABC(N)123456",
            "passportNo": "",
            "passportExpiry": "",
            "issuedCountry": "Myanmar",
            "remark": "",
        ]
        let contact: JSON = [
            "title": "Mr",
            "firstName": "Aung",
            "lastName": "Aung",
            "fullName": "Aung Aung",
            "email": "traveller@example.com",
            "phone": "09795000000",
            "countryCode": "+95",
        ]
        let request = FlightHoldRequest(
            selections: [FlightHoldRequest.selectionFrom(flight)],
            passengers: [passenger],
            contact: contact
        )

        let payload = request.toJson(accessToken: "access-token")
        XCTAssertTrue(Dart.isNull(payload["paymentMethod"]))
        let passengers = Dart.maps(payload["passengers"])
        XCTAssertEqual(passengers.count, 1)
        XCTAssertEqual(NSDictionary(dictionary: passengers[0]), NSDictionary(dictionary: passenger))
        XCTAssertEqual(
            NSDictionary(dictionary: Dart.map(payload["contact"]) ?? [:]),
            NSDictionary(dictionary: contact)
        )
        XCTAssertEqual(Dart.str(payload["accessToken"]), "access-token")
    }

    private func json(_ text: String) throws -> JSON {
        try XCTUnwrap(Dart.map(try jsonDecode(text)))
    }
}
