// Port of lib/features/booking/data/datasources/booking_mock_service.dart

import Foundation

/// In-memory stand-in for the booking/search endpoints.
///
/// `BookingRepositoryImpl` talks to this while the backend is being built; swap
/// it for `BookingRemoteService` there and nothing above the repository moves.
final class BookingMockService {
    init() {}

    // ---- Instance API used by the repository -------------------------------
    // The statics below stay static because the ticket fixtures build on them.

    func getLocations() -> [LocationModel] { Self.locations }

    func searchTrips(
        mode: TravelMode,
        date: DateTime,
        from: LocationModel? = nil,
        to: LocationModel? = nil
    ) -> [TripOptionModel] {
        Self.sampleTrips(mode: mode, dayAnchor: date, from: from, to: to)
    }

    /// Airports / terminals for the From–To location picker. In production this
    /// comes from a `/locations` endpoint (cacheable).
    static let locations: [LocationModel] = [
        // ── Myanmar (index 0 & 1 are the defaults) ──────────────────────────────
        LocationModel(code: "RGN", city: "Yangon", facilityName: "Yangon International Airport", country: "Myanmar"),
        LocationModel(code: "MDL", city: "Mandalay", facilityName: "Mandalay International Airport", country: "Myanmar"),
        LocationModel(code: "NYT", city: "Nay Pyi Taw", facilityName: "Nay Pyi Taw International Airport", country: "Myanmar"),
        LocationModel(code: "HEH", city: "Heho", facilityName: "Heho Airport", country: "Myanmar"),
        LocationModel(code: "NYU", city: "Bagan", facilityName: "Nyaung U Airport", country: "Myanmar"),
        LocationModel(code: "THL", city: "Tachilek", facilityName: "Tachilek Airport", country: "Myanmar"),
        LocationModel(code: "MGZ", city: "Myeik", facilityName: "Myeik Airport", country: "Myanmar"),
        LocationModel(code: "KAW", city: "Kawthaung", facilityName: "Kawthaung Airport", country: "Myanmar"),
        LocationModel(code: "SNW", city: "Thandwe", facilityName: "Thandwe Airport (Ngapali)", country: "Myanmar"),
        LocationModel(code: "AKY", city: "Sittwe", facilityName: "Sittwe Airport", country: "Myanmar"),
        LocationModel(code: "MYT", city: "Myitkyina", facilityName: "Myitkyina Airport", country: "Myanmar"),
        LocationModel(code: "LSH", city: "Lashio", facilityName: "Lashio Airport", country: "Myanmar"),
        // ── Thailand ────────────────────────────────────────────────────────────
        LocationModel(code: "BKK", city: "Bangkok", facilityName: "Suvarnabhumi Airport", country: "Thailand"),
        LocationModel(code: "DMK", city: "Bangkok", facilityName: "Don Mueang International Airport", country: "Thailand"),
        LocationModel(code: "CNX", city: "Chiang Mai", facilityName: "Chiang Mai International Airport", country: "Thailand"),
        LocationModel(code: "HKT", city: "Phuket", facilityName: "Phuket International Airport", country: "Thailand"),
        LocationModel(code: "USM", city: "Koh Samui", facilityName: "Samui Airport", country: "Thailand"),
        // ── Singapore ───────────────────────────────────────────────────────────
        LocationModel(code: "SIN", city: "Singapore", facilityName: "Singapore Changi Airport", country: "Singapore"),
        // ── Malaysia ────────────────────────────────────────────────────────────
        LocationModel(code: "KUL", city: "Kuala Lumpur", facilityName: "Kuala Lumpur International Airport", country: "Malaysia"),
        LocationModel(code: "PEN", city: "Penang", facilityName: "Penang International Airport", country: "Malaysia"),
        LocationModel(code: "BKI", city: "Kota Kinabalu", facilityName: "Kota Kinabalu International Airport", country: "Malaysia"),
        // ── Vietnam ─────────────────────────────────────────────────────────────
        LocationModel(code: "SGN", city: "Ho Chi Minh City", facilityName: "Tan Son Nhat International Airport", country: "Vietnam"),
        LocationModel(code: "HAN", city: "Hanoi", facilityName: "Noi Bai International Airport", country: "Vietnam"),
        LocationModel(code: "DAD", city: "Da Nang", facilityName: "Da Nang International Airport", country: "Vietnam"),
        // ── Indonesia ───────────────────────────────────────────────────────────
        LocationModel(code: "CGK", city: "Jakarta", facilityName: "Soekarno–Hatta International Airport", country: "Indonesia"),
        LocationModel(code: "DPS", city: "Denpasar", facilityName: "Ngurah Rai International Airport (Bali)", country: "Indonesia"),
        // ── Philippines ─────────────────────────────────────────────────────────
        LocationModel(code: "MNL", city: "Manila", facilityName: "Ninoy Aquino International Airport", country: "Philippines"),
        LocationModel(code: "CEB", city: "Cebu", facilityName: "Mactan–Cebu International Airport", country: "Philippines"),
        // ── Cambodia ────────────────────────────────────────────────────────────
        LocationModel(code: "PNH", city: "Phnom Penh", facilityName: "Phnom Penh International Airport", country: "Cambodia"),
        LocationModel(code: "REP", city: "Siem Reap", facilityName: "Siem Reap–Angkor International Airport", country: "Cambodia"),
        // ── Laos & Brunei ───────────────────────────────────────────────────────
        LocationModel(code: "VTE", city: "Vientiane", facilityName: "Wattay International Airport", country: "Laos"),
        LocationModel(code: "BWN", city: "Bandar Seri Begawan", facilityName: "Brunei International Airport", country: "Brunei"),
        // ── Hong Kong · Taiwan · China ──────────────────────────────────────────
        LocationModel(code: "HKG", city: "Hong Kong", facilityName: "Hong Kong International Airport", country: "Hong Kong"),
        LocationModel(code: "TPE", city: "Taipei", facilityName: "Taiwan Taoyuan International Airport", country: "Taiwan"),
        LocationModel(code: "PVG", city: "Shanghai", facilityName: "Shanghai Pudong International Airport", country: "China"),
        LocationModel(code: "PEK", city: "Beijing", facilityName: "Beijing Capital International Airport", country: "China"),
        LocationModel(code: "CAN", city: "Guangzhou", facilityName: "Guangzhou Baiyun International Airport", country: "China"),
        LocationModel(code: "KMG", city: "Kunming", facilityName: "Kunming Changshui International Airport", country: "China"),
        // ── Japan · South Korea ─────────────────────────────────────────────────
        LocationModel(code: "NRT", city: "Tokyo", facilityName: "Narita International Airport", country: "Japan"),
        LocationModel(code: "HND", city: "Tokyo", facilityName: "Haneda Airport", country: "Japan"),
        LocationModel(code: "KIX", city: "Osaka", facilityName: "Kansai International Airport", country: "Japan"),
        LocationModel(code: "ICN", city: "Seoul", facilityName: "Incheon International Airport", country: "South Korea"),
        LocationModel(code: "GMP", city: "Seoul", facilityName: "Gimpo International Airport", country: "South Korea"),
        // ── South Asia ──────────────────────────────────────────────────────────
        LocationModel(code: "DAC", city: "Dhaka", facilityName: "Hazrat Shahjalal International Airport", country: "Bangladesh"),
        LocationModel(code: "CCU", city: "Kolkata", facilityName: "Netaji Subhas Chandra Bose International Airport", country: "India"),
        LocationModel(code: "DEL", city: "Delhi", facilityName: "Indira Gandhi International Airport", country: "India"),
        LocationModel(code: "BOM", city: "Mumbai", facilityName: "Chhatrapati Shivaji Maharaj International Airport", country: "India"),
        LocationModel(code: "MAA", city: "Chennai", facilityName: "Chennai International Airport", country: "India"),
        LocationModel(code: "BLR", city: "Bengaluru", facilityName: "Kempegowda International Airport", country: "India"),
        LocationModel(code: "CMB", city: "Colombo", facilityName: "Bandaranaike International Airport", country: "Sri Lanka"),
        LocationModel(code: "KTM", city: "Kathmandu", facilityName: "Tribhuvan International Airport", country: "Nepal"),
        // ── Middle East ─────────────────────────────────────────────────────────
        LocationModel(code: "DXB", city: "Dubai", facilityName: "Dubai International Airport", country: "United Arab Emirates"),
        LocationModel(code: "AUH", city: "Abu Dhabi", facilityName: "Zayed International Airport", country: "United Arab Emirates"),
        LocationModel(code: "DOH", city: "Doha", facilityName: "Hamad International Airport", country: "Qatar"),
        LocationModel(code: "IST", city: "Istanbul", facilityName: "Istanbul Airport", country: "Türkiye"),
        // ── Europe ──────────────────────────────────────────────────────────────
        LocationModel(code: "LHR", city: "London", facilityName: "Heathrow Airport", country: "United Kingdom"),
        LocationModel(code: "CDG", city: "Paris", facilityName: "Charles de Gaulle Airport", country: "France"),
        LocationModel(code: "FRA", city: "Frankfurt", facilityName: "Frankfurt Airport", country: "Germany"),
        LocationModel(code: "AMS", city: "Amsterdam", facilityName: "Amsterdam Airport Schiphol", country: "Netherlands"),
        // ── Oceania ─────────────────────────────────────────────────────────────
        LocationModel(code: "SYD", city: "Sydney", facilityName: "Sydney Kingsford Smith Airport", country: "Australia"),
        LocationModel(code: "MEL", city: "Melbourne", facilityName: "Melbourne Airport", country: "Australia"),
        // ── North America ───────────────────────────────────────────────────────
        LocationModel(code: "LAX", city: "Los Angeles", facilityName: "Los Angeles International Airport", country: "United States"),
        LocationModel(code: "JFK", city: "New York", facilityName: "John F. Kennedy International Airport", country: "United States"),
        LocationModel(code: "SFO", city: "San Francisco", facilityName: "San Francisco International Airport", country: "United States"),
    ]

    static var defaultFrom: LocationModel { LocationModel.defaultOrigin } // Yangon
    static var defaultTo: LocationModel { LocationModel.defaultDestination } // Mandalay

    /// Generates a small set of trip options for a given route/date so the
    /// results screen has something to render. `dayAnchor` lets callers pin the
    /// generated times to a chosen travel date.
    static func sampleTrips(
        mode: TravelMode,
        dayAnchor: DateTime,
        from: LocationModel? = nil,
        to: LocationModel? = nil
    ) -> [TripOptionModel] {
        let origin = from ?? defaultFrom
        let dest = to ?? defaultTo
        let base = DateTime(dayAnchor.year, dayAnchor.month, dayAnchor.day, 6)
        let operators = mode == .flight
            ? ["MAI Airway", "Air KBZ", "Air Thanlwin"]
            : ["JJ Express", "Elite Express", "Mandalar Minn"]

        return (0..<(operators.count * 2)).map { i in
            let dep = base.add(Duration(hours: i * 3))
            let dur = mode == .flight
                ? Duration(minutes: 80 + (i % 3) * 25)
                : Duration(hours: 8 + (i % 3))
            return TripOptionModel(
                id: "\(mode.name)_\(i)",
                mode: mode,
                operatorName: operators[i % operators.count],
                operatorLogoUrl: AppAssets.airlineLogoUrl(operators[i % operators.count]),
                originCode: origin.code,
                originName: origin.city,
                destinationCode: dest.code,
                destinationName: dest.city,
                departure: dep,
                arrival: dep.add(dur),
                stops: i % 3 == 0 ? 0 : (i % 3 == 1 ? 1 : 2),
                // Cycle through all cabin classes so the result list shows the full
                // range of class badges (Economy / Premium Economy / Business / First).
                travelClass: TravelClass.values[i % TravelClass.values.count],
                price: Double(49000 + (i * 7500) + (mode == .flight ? 60000 : 0)),
                currency: "MMK"
            )
        }
    }
}
