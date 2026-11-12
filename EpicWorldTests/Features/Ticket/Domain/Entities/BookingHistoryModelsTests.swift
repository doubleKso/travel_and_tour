// Port of test/features/ticket/domain/entities/booking_history_models_test.dart
import XCTest
@testable import EpicWorld

final class BookingHistoryModelsTests: XCTestCase {
    func testMapsGetMyBookingsSegmentsAndPassengersResponses() {
        let booking = BookingHistoryItem.fromJson([
            "id": "booking-1",
            "reference": "EW-DGPZNC",
            "pnr": "17RDGN",
            "service": "air",
            "mode": "flight",
            "tripType": "one-way",
            "cabin": "economy",
            "adults": 1,
            "children": 0,
            "infants": 0,
            "status": "held",
            "currency": "MMK",
            "route": "RGN → SIN",
            "perPaxFare": 451200,
            "total": 451200,
            "contactFullName": "Zeck Dhwye",
            "contactTitle": "Mr",
            "contactCountryCode": "+95",
            "contactPhone": "9259807040",
            "contactEmail": "traveller@example.com",
            "createdAt": "2026-08-24T07:18:42.236663Z",
            "ticketTimeLimit": "2026-08-24T12:18:38.000000Z",
        ])
        let segment = BookingHistorySegment.fromJson([
            "direction": "outbound",
            "fromCode": "RGN",
            "toCode": "SIN",
            "travelDate": "2026-08-25",
            "departTime": "03:40 PM",
            "arriveTime": "08:10 PM",
            "flightNo": "8M233",
            "carrierName": "MYANMAR AIRWAYS",
            "cabin": "ECONOMY",
            "stops": 0,
            "baggageKg": 30,
            "price": 451200,
            "refundable": false,
            "fareBrand": "IECO SPECIAL",
        ])
        let passenger = BookingHistoryPassenger.fromJson([
            "title": "Mr",
            "firstName": "Ci",
            "lastName": "Phat",
            "type": "adult",
            "gender": "male",
            "dob": "1995-08-16",
            "nationality": "Myanmar",
            "nrc": "14/MaPaNa(N)943783",
            "passportNo": "MA73387272",
        ])

        XCTAssertEqual(booking.passengerCount, 1)
        XCTAssertTrue(booking.isHeld)
        XCTAssertEqual(booking.total, 451200)
        XCTAssertEqual(segment.flightNo, "8M233")
        XCTAssertEqual(segment.baggageKg, 30)
        XCTAssertEqual(passenger.fullName, "Mr Ci Phat")
    }
}
