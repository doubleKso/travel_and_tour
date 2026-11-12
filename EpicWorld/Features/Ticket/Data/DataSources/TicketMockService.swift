// Port of lib/features/ticket/data/datasources/ticket_mock_service.dart
import Foundation

/// In-memory stand-in for the "my tickets" endpoint.
final class TicketMockService {
    init() {}

    /// Instance entry point used by `TicketRepositoryImpl`.
    func getTickets(_ now: DateTime) -> [TicketModel] { Self.tickets(now) }

    /// ~10 sample tickets across a spread of dates (some sharing a date so the
    /// History screen's date grouping is visible), mixing flights and buses.
    static func tickets(_ now: DateTime) -> [TicketModel] {
        // (isFlight, dayOffset, operatorIndex, seats) — two pairs share a date.
        let specs: [(Bool, Int, Int, Int)] = [
            (true, 7, 0, 1),
            (true, 7, 3, 2), // same date as above (upcoming)
            (false, 4, 1, 1),
            (true, 1, 2, 1),
            (false, -2, 0, 1),
            (true, -2, 5, 2), // same date as above (past)
            (false, -9, 2, 1),
            (true, -16, 1, 1),
            (true, -24, 4, 1),
            (false, -33, 0, 2),
        ]
        let refs = [
            "EW-7F3K9Q",
            "EW-2M8L0P",
            "EW-9QX4D2",
            "EW-3KP7M1",
            "EW-8LZ6R0",
            "EW-1VN5T8",
            "EW-6HB2W4",
            "EW-4RC9J7",
            "EW-0YD3F5",
            "EW-5GK8N2",
        ]

        var result: [TicketModel] = [
            // A round-trip booking (3 passengers) — the newest ticket, so it lands
            // at the top of History and exercises the two-leg / multi-passenger views.
            roundTripTicket(now),
            // A non-MAI reservation (unpaid) — shows the "Reserved" History card.
            reservationSample(now),
        ]
        for i in 0..<specs.count {
            result.append(ticketFrom(now, spec: specs[i], ref: refs[i], seq: i))
        }
        return result
    }

    /// A sample non-MAI (Air KBZ) reservation — held, not yet paid.
    private static func reservationSample(_ now: DateTime) -> TicketModel {
        let day = now.add(Duration(days: 6))
        let dep = DateTime(day.year, day.month, day.day, 8)
        let outbound = TripOptionModel(
            id: "rsv_out",
            mode: .flight,
            operatorName: "Air KBZ",
            operatorLogoUrl: AppAssets.airlineLogoUrl("Air KBZ"),
            originCode: "RGN",
            originName: "Yangon",
            destinationCode: "MDL",
            destinationName: "Mandalay",
            departure: dep,
            arrival: dep.add(Duration(hours: 1, minutes: 10)),
            stops: 0,
            travelClass: .economy,
            price: 138000,
            currency: "MMK"
        )
        return TicketModel(
            id: "rsv_1",
            bookingReference: "RSV-4KD9Q2",
            outbound: outbound,
            inbound: nil,
            passengerName: "Hpone Pyae",
            seatCount: 1,
            totalPaid: 0,
            currency: "MMK",
            issuedAt: now,
            qrPayload: "RSV-4KD9Q2|reservation",
            isReservation: true,
            phone: "09 5123 4567",
            email: "hponepyae@example.com",
            message: "Window seat if possible, travelling with one check-in bag."
        )
    }

    /// A RGN⇄MDL round trip for 3 adults, dated further out than any one-way
    /// sample so it sorts to the top of the History list.
    private static func roundTripTicket(_ now: DateTime) -> TicketModel {
        let outDay = now.add(Duration(days: 10))
        let inDay = now.add(Duration(days: 13))
        let outDep = DateTime(outDay.year, outDay.month, outDay.day, 6)
        let inDep = DateTime(inDay.year, inDay.month, inDay.day, 9)

        let outbound = TripOptionModel(
            id: "rt_out",
            mode: .flight,
            operatorName: "MAI Airway",
            operatorLogoUrl: AppAssets.airlineLogoUrl("MAI Airway"),
            originCode: "RGN",
            originName: "Yangon",
            destinationCode: "MDL",
            destinationName: "Mandalay",
            departure: outDep,
            arrival: outDep.add(Duration(hours: 1, minutes: 20)),
            stops: 0,
            travelClass: .economy,
            price: 165000,
            currency: "MMK"
        )
        let inbound = TripOptionModel(
            id: "rt_in",
            mode: .flight,
            operatorName: "Air KBZ",
            operatorLogoUrl: AppAssets.airlineLogoUrl("Air KBZ"),
            originCode: "MDL",
            originName: "Mandalay",
            destinationCode: "RGN",
            destinationName: "Yangon",
            departure: inDep,
            arrival: inDep.add(Duration(hours: 1, minutes: 45)),
            stops: 1,
            travelClass: .economy,
            price: 175000,
            currency: "MMK"
        )
        let seats = 3
        return TicketModel(
            id: "rt1",
            bookingReference: "EW-RT7788",
            outbound: outbound,
            inbound: inbound,
            passengerName: "Hein Htet Zaw",
            seatCount: seats,
            totalPaid: (outbound.price + inbound.price) * Double(seats),
            currency: "MMK",
            issuedAt: now.add(Duration(days: 3)),
            qrPayload: "EW-RT7788|rt1"
        )
    }

    private static func ticketFrom(
        _ now: DateTime,
        spec: (Bool, Int, Int, Int),
        ref: String,
        seq: Int
    ) -> TicketModel {
        let (isFlight, dayOffset, opIndex, seats) = spec
        let mode: TravelMode = isFlight ? .flight : .bus
        let trips = BookingMockService.sampleTrips(
            mode: mode,
            dayAnchor: now.add(Duration(days: dayOffset))
        )
        let trip = trips[opIndex % trips.count]
        return TicketModel(
            id: "t\(seq + 1)",
            bookingReference: ref,
            outbound: trip,
            inbound: nil,
            passengerName: "Hein Htet Zaw",
            seatCount: seats,
            totalPaid: trip.price * Double(seats),
            currency: trip.currency,
            issuedAt: now.add(Duration(days: dayOffset - 2)),
            qrPayload: "\(ref)|t\(seq + 1)"
        )
    }
}
