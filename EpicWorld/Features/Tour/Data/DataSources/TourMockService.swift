// Port of lib/features/tour/data/datasources/tour_mock_service.dart

import Foundation

/// In-memory stand-in for the tour-packages endpoint.
struct TourMockService {
    init() {}

    /// Instance entry point used by `TourRepositoryImpl`.
    func getPackages() -> [TourPackage] { Self.packages }

    /// Every tour shown on the Tour screen grid.
    static let packages: [TourPackage] = [
        malaysia,
        threeCountries,
        kashmir,
        singapore,
        bangkok,
        bali,
    ]

    // -------------------------------------------------------------------------
    // 1. Malaysia Delight Tour — fully detailed reference package.
    // -------------------------------------------------------------------------
    private static let malaysia = TourPackage(
        id: "malaysia-delight",
        title: "Malaysia Delight Tour",
        countryCode: "my",
        country: "Malaysia",
        duration: "3 Nights / 4 Days",
        route: "Kuala Lumpur — Genting Highlands — Batu Caves — Malacca",
        imageUrl: "https://images.unsplash.com/photo-1596422846543-75c6fc197f07?w=1200",
        priceFrom: 690000,
        currency: "MMK",
        overview: "Discover the best of Malaysia in one delightful journey — from the towering skyline of Kuala Lumpur to the cool hilltop fun of Genting Highlands, the sacred Batu Caves and the historic charm of Malacca. Fully guided by an experienced Epic World tour leader.",
        highlights: [
            "Petronas Twin Towers & KLCC Park",
            "Genting Highlands cable car & theme park",
            "Batu Caves sacred shrine visit",
            "Historic UNESCO town of Malacca",
            "City tour with Merdeka Square",
            "Local food & shopping experiences",
        ],
        sightseeing: [
            TourSpot(
                "Kuala Lumpur",
                "https://images.unsplash.com/photo-1596422846543-75c6fc197f07?w=600"
            ),
            TourSpot(
                "Genting Highlands",
                "https://images.unsplash.com/photo-1552465011-b4e21bf6e79a?w=600"
            ),
            TourSpot(
                "Batu Caves",
                "https://images.unsplash.com/photo-1570789210967-2cac24afeb00?w=600"
            ),
            TourSpot(
                "Malacca",
                "https://images.unsplash.com/photo-1512100356356-de1b84283e18?w=600"
            ),
        ],
        itinerary: [
            TourDay(
                "Arrival in Kuala Lumpur",
                "Airport pickup and city tour — Petronas Towers, Merdeka Square and KLCC by night."
            ),
            TourDay(
                "Genting Highlands",
                "Cable car up to the hilltop resort for theme parks, cool weather and panoramic views."
            ),
            TourDay(
                "Batu Caves & Malacca",
                "Morning at the Batu Caves shrine, then drive to the historic UNESCO town of Malacca."
            ),
            TourDay(
                "Departure",
                "Free morning for shopping before your transfer to the airport."
            ),
        ],
        included: [
            "Round-trip Air Tickets (30Kg + 7Kg)",
            "3 nights accommodation in a 4-star hotel",
            "Daily breakfast & selected meals",
            "Private air-conditioned transport",
            "English / Myanmar speaking tour guide",
            "All entrance fees per itinerary",
        ],
        notIncluded: [
            "Visa fees",
            "Travel insurance",
            "Personal expenses & tips",
            "Optional activities",
        ]
    )

    // -------------------------------------------------------------------------
    // 2. 3 Countries Tour: Vietnam, Cambodia & Thailand
    // -------------------------------------------------------------------------
    private static let threeCountries = TourPackage(
        id: "three-countries",
        title: "3 Countries Tour: Vietnam, Cambodia & Thailand",
        countryCode: "vn",
        country: "Vietnam · Cambodia · Thailand",
        duration: "5 Nights / 6 Days",
        route: "Ho Chi Minh — Siem Reap — Bangkok",
        imageUrl: "https://images.unsplash.com/photo-1528127269322-539801943592?w=1200",
        priceFrom: 1450000,
        currency: "MMK",
        overview: "Three unforgettable countries in one seamless journey — cruise the emerald waters of Halong Bay, stand in awe before the temples of Angkor, and soak up the buzz of Bangkok. A grand tour of Indochina led end-to-end by your Epic World team.",
        highlights: [
            "Halong Bay overnight cruise",
            "Angkor Wat sunrise visit",
            "Bangkok Grand Palace & temples",
            "Mekong Delta river life",
            "Cross-border guided transfers",
            "Authentic street-food tastings",
        ],
        sightseeing: [
            TourSpot(
                "Halong Bay",
                "https://images.unsplash.com/photo-1528127269322-539801943592?w=600"
            ),
            TourSpot(
                "Angkor Wat",
                "https://images.unsplash.com/photo-1508009603885-50cf7c579365?w=600"
            ),
            TourSpot(
                "Bangkok",
                "https://images.unsplash.com/photo-1563492065599-3520f775eeed?w=600"
            ),
            TourSpot(
                "Mekong Delta",
                "https://images.unsplash.com/photo-1583417319070-4a69db38a482?w=600"
            ),
        ],
        itinerary: [
            TourDay(
                "Arrival in Ho Chi Minh City",
                "Airport pickup, city orientation tour and a welcome dinner."
            ),
            TourDay(
                "Mekong Delta",
                "Full-day river cruise through floating markets and orchards."
            ),
            TourDay(
                "Fly to Siem Reap",
                "Evening arrival in Cambodia and a cultural Apsara show."
            ),
            TourDay(
                "Angkor Wat",
                "Sunrise at Angkor Wat and a full day exploring the temple complex."
            ),
            TourDay(
                "Fly to Bangkok",
                "Grand Palace, Wat Pho and a riverside evening."
            ),
            TourDay(
                "Departure",
                "Free morning for shopping before your transfer to the airport."
            ),
        ],
        included: [
            "Round-trip & inter-country Air Tickets",
            "5 nights accommodation in 4-star hotels",
            "Daily breakfast & selected meals",
            "Private air-conditioned transport",
            "English / Myanmar speaking tour guide",
            "All entrance fees per itinerary",
        ],
        notIncluded: [
            "Visa fees for each country",
            "Travel insurance",
            "Personal expenses & tips",
            "Optional activities",
        ]
    )

    // -------------------------------------------------------------------------
    // 3. Heaven in Snow: Kashmir Tour
    // -------------------------------------------------------------------------
    private static let kashmir = TourPackage(
        id: "kashmir-snow",
        title: "Heaven in Snow: Kashmir Tour",
        countryCode: "in",
        country: "India · Kashmir",
        duration: "6 Nights / 7 Days",
        route: "Srinagar — Gulmarg — Pahalgam — Sonamarg",
        imageUrl: "https://images.unsplash.com/photo-1566837945700-30057527ade0?w=1200",
        priceFrom: 1780000,
        currency: "MMK",
        overview: "Step into a snow-draped paradise. Glide across Dal Lake on a traditional shikara, ride the Gulmarg gondola into the Himalayas, and wander the meadows of Pahalgam and Sonamarg. Kashmir at its most breathtaking, fully guided by Epic World.",
        highlights: [
            "Shikara ride on Dal Lake",
            "Gulmarg gondola cable car",
            "Pahalgam valley excursion",
            "Sonamarg snow meadows",
            "Mughal gardens of Srinagar",
            "Stay in a traditional houseboat",
        ],
        sightseeing: [
            TourSpot(
                "Srinagar",
                "https://images.unsplash.com/photo-1566837945700-30057527ade0?w=600"
            ),
            TourSpot(
                "Gulmarg",
                "https://images.unsplash.com/photo-1626621341517-bbf3d9990a23?w=600"
            ),
            TourSpot(
                "Pahalgam",
                "https://images.unsplash.com/photo-1595815771614-ade9d652a65d?w=600"
            ),
            TourSpot(
                "Sonamarg",
                "https://images.unsplash.com/photo-1610375461369-d613b564f4c4?w=600"
            ),
        ],
        itinerary: [
            TourDay(
                "Arrival in Srinagar",
                "Transfer to your houseboat and an evening shikara ride on Dal Lake."
            ),
            TourDay(
                "Srinagar city",
                "Mughal gardens, Shankaracharya Temple and the old bazaar."
            ),
            TourDay(
                "Gulmarg",
                "Day trip for the gondola ride and snow activities."
            ),
            TourDay(
                "Pahalgam",
                "Scenic drive through saffron fields to the valley of shepherds."
            ),
            TourDay(
                "Sonamarg",
                "The \"meadow of gold\" — glaciers, snow points and river views."
            ),
            TourDay(
                "Leisure & shopping",
                "Free day for handicrafts, pashmina and local cuisine."
            ),
            TourDay(
                "Departure",
                "Transfer to Srinagar airport for your flight home."
            ),
        ],
        included: [
            "Round-trip Air Tickets (30Kg + 7Kg)",
            "6 nights accommodation incl. houseboat stay",
            "Daily breakfast & dinner",
            "Private air-conditioned transport",
            "English / Myanmar speaking tour guide",
            "All entrance fees per itinerary",
        ],
        notIncluded: [
            "Visa fees",
            "Travel insurance",
            "Gondola phase-2 ticket",
            "Personal expenses & tips",
        ]
    )

    // -------------------------------------------------------------------------
    // 4. Singapore City Highlights
    // -------------------------------------------------------------------------
    private static let singapore = TourPackage(
        id: "singapore-highlights",
        title: "Singapore City Highlights",
        countryCode: "sg",
        country: "Singapore",
        duration: "3 Nights / 4 Days",
        route: "Marina Bay — Sentosa — Gardens by the Bay",
        imageUrl: "https://images.unsplash.com/photo-1525625293386-3f8f99389edd?w=1200",
        priceFrom: 980000,
        currency: "MMK",
        overview: "The Lion City in all its glory — marvel at Marina Bay Sands, wander the futuristic Gardens by the Bay, and spend a full day of fun on Sentosa Island. A polished city break planned down to every detail by Epic World.",
        highlights: [
            "Marina Bay Sands SkyPark",
            "Gardens by the Bay light show",
            "Sentosa Island & Universal Studios",
            "Merlion Park & city tour",
            "Orchard Road shopping",
            "Night Safari experience",
        ],
        sightseeing: [
            TourSpot(
                "Marina Bay",
                "https://images.unsplash.com/photo-1525625293386-3f8f99389edd?w=600"
            ),
            TourSpot(
                "Gardens by the Bay",
                "https://images.unsplash.com/photo-1508964942454-1a56651d54ac?w=600"
            ),
            TourSpot(
                "Sentosa",
                "https://images.unsplash.com/photo-1533395427226-788cee25cc7b?w=600"
            ),
            TourSpot(
                "Merlion Park",
                "https://images.unsplash.com/photo-1542114633-b5e0eec2ee16?w=600"
            ),
        ],
        itinerary: [
            TourDay(
                "Arrival in Singapore",
                "Airport pickup and an evening at Gardens by the Bay light show."
            ),
            TourDay(
                "City tour",
                "Merlion Park, Chinatown, Little India and Orchard Road."
            ),
            TourDay(
                "Sentosa Island",
                "Full day of theme parks, cable car and the beach."
            ),
            TourDay(
                "Departure",
                "Free morning for shopping before your transfer to the airport."
            ),
        ],
        included: [
            "Round-trip Air Tickets (30Kg + 7Kg)",
            "3 nights accommodation in a 4-star hotel",
            "Daily breakfast",
            "Private air-conditioned transport",
            "English / Myanmar speaking tour guide",
            "Selected attraction tickets",
        ],
        notIncluded: [
            "Visa fees",
            "Travel insurance",
            "Personal expenses & tips",
            "Optional activities",
        ]
    )

    // -------------------------------------------------------------------------
    // 5. Bangkok & Pattaya Getaway
    // -------------------------------------------------------------------------
    private static let bangkok = TourPackage(
        id: "bangkok-pattaya",
        title: "Bangkok & Pattaya Getaway",
        countryCode: "th",
        country: "Thailand",
        duration: "4 Nights / 5 Days",
        route: "Bangkok — Pattaya — Coral Island",
        imageUrl: "https://images.unsplash.com/photo-1508009603885-50cf7c579365?w=1200",
        priceFrom: 850000,
        currency: "MMK",
        overview: "The perfect blend of city buzz and beach bliss — temples and markets in Bangkok, then sun, sea and island-hopping in Pattaya. A relaxed, crowd-pleasing getaway fully guided by your Epic World tour leader.",
        highlights: [
            "Grand Palace & Wat Arun",
            "Pattaya Coral Island trip",
            "Floating market experience",
            "Nong Nooch tropical garden",
            "Chao Phraya river dinner cruise",
            "Shopping at ICONSIAM",
        ],
        sightseeing: [
            TourSpot(
                "Bangkok",
                "https://images.unsplash.com/photo-1508009603885-50cf7c579365?w=600"
            ),
            TourSpot(
                "Pattaya",
                "https://images.unsplash.com/photo-1552465011-b4e21bf6e79a?w=600"
            ),
            TourSpot(
                "Coral Island",
                "https://images.unsplash.com/photo-1537956965359-7573183d1f57?w=600"
            ),
            TourSpot(
                "Floating Market",
                "https://images.unsplash.com/photo-1563492065599-3520f775eeed?w=600"
            ),
        ],
        itinerary: [
            TourDay(
                "Arrival in Bangkok",
                "Airport pickup and an evening Chao Phraya dinner cruise."
            ),
            TourDay(
                "Bangkok temples",
                "Grand Palace, Wat Pho and the floating market."
            ),
            TourDay(
                "Transfer to Pattaya",
                "Nong Nooch garden en route, evening at leisure by the beach."
            ),
            TourDay(
                "Coral Island",
                "Speedboat to Coral Island for water sports and beach time."
            ),
            TourDay(
                "Departure",
                "Shopping stop before your transfer to Bangkok airport."
            ),
        ],
        included: [
            "Round-trip Air Tickets (30Kg + 7Kg)",
            "4 nights accommodation in 4-star hotels",
            "Daily breakfast & selected meals",
            "Private air-conditioned transport",
            "English / Myanmar speaking tour guide",
            "All entrance fees per itinerary",
        ],
        notIncluded: [
            "Visa fees",
            "Travel insurance",
            "Personal expenses & tips",
            "Optional water sports",
        ]
    )

    // -------------------------------------------------------------------------
    // 6. Bali Island Escape
    // -------------------------------------------------------------------------
    private static let bali = TourPackage(
        id: "bali-escape",
        title: "Bali Island Escape",
        countryCode: "id",
        country: "Indonesia · Bali",
        duration: "4 Nights / 5 Days",
        route: "Ubud — Kintamani — Tanah Lot — Uluwatu",
        imageUrl: "https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=1200",
        priceFrom: 1120000,
        currency: "MMK",
        overview: "The Island of the Gods awaits — emerald rice terraces in Ubud, the volcanic views of Kintamani, and sunset temples over the sea at Tanah Lot and Uluwatu. A soulful, scenic escape curated by Epic World.",
        highlights: [
            "Ubud rice terraces & art villages",
            "Kintamani volcano viewpoint",
            "Tanah Lot sunset temple",
            "Uluwatu cliff & Kecak dance",
            "Sacred Monkey Forest",
            "Balinese spa experience",
        ],
        sightseeing: [
            TourSpot(
                "Ubud",
                "https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=600"
            ),
            TourSpot(
                "Kintamani",
                "https://images.unsplash.com/photo-1518548419970-58e3b4079ab2?w=600"
            ),
            TourSpot(
                "Tanah Lot",
                "https://images.unsplash.com/photo-1604999333679-b86d54738315?w=600"
            ),
            TourSpot(
                "Uluwatu",
                "https://images.unsplash.com/photo-1573790387438-4da905039392?w=600"
            ),
        ],
        itinerary: [
            TourDay(
                "Arrival in Bali",
                "Airport pickup and transfer to your resort, evening at leisure."
            ),
            TourDay(
                "Ubud",
                "Rice terraces, Monkey Forest and traditional art villages."
            ),
            TourDay(
                "Kintamani",
                "Volcano viewpoint, coffee plantation and holy springs."
            ),
            TourDay(
                "Tanah Lot & Uluwatu",
                "Sea temples by day and a cliffside Kecak dance at sunset."
            ),
            TourDay(
                "Departure",
                "Free morning for the beach before your transfer to the airport."
            ),
        ],
        included: [
            "Round-trip Air Tickets (30Kg + 7Kg)",
            "4 nights accommodation in a resort",
            "Daily breakfast & selected meals",
            "Private air-conditioned transport",
            "English / Myanmar speaking tour guide",
            "All entrance fees per itinerary",
        ],
        notIncluded: [
            "Visa fees",
            "Travel insurance",
            "Personal expenses & tips",
            "Optional spa treatments",
        ]
    )
}
