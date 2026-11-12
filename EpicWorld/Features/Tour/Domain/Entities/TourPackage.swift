// Port of lib/features/tour/domain/entities/tour_package.dart

import Foundation

// Data for the Tour Package feature — the list of curated tours shown on the
// Tour screen and the rich content each one's detail page renders.
//
// Kept self-contained in the tour feature folder (like the visa screen's inline
// data): it's presentation content, not something the booking API serves yet.
// Swap `TourPackage.all` for a repository call when the tours endpoint lands.

/// One curated tour package — enough content to render both the summary card on
/// the Tour screen and the full detail page (overview, highlights, sightseeing,
/// day-by-day itinerary, and what's included / excluded).
struct TourPackage {
    let id: String

    /// Card / detail headline, e.g. "Malaysia Delight Tour".
    let title: String

    /// ISO 3166-1 alpha-2 country code (lowercase) used to fetch the flag.
    let countryCode: String

    /// Display country / region, shown under the hero title.
    let country: String

    /// Human duration label, e.g. "3 Nights / 4 Days".
    let duration: String

    /// Route summary, e.g. "Kuala Lumpur — Genting Highlands — Batu Caves".
    let route: String

    /// Hero / card background photo.
    let imageUrl: String

    /// "Starting from" price per person and its currency.
    let priceFrom: Int
    let currency: String

    /// Long-form intro paragraph for the Overview section.
    let overview: String

    /// Bullet highlights, each rendered as a ticked card.
    let highlights: [String]

    /// Sightseeing spots (name + photo) shown as a horizontal image strip.
    let sightseeing: [TourSpot]

    /// Day-by-day itinerary steps.
    let itinerary: [TourDay]

    /// What the price covers / what it doesn't.
    let included: [String]
    let notIncluded: [String]

    init(
        id: String,
        title: String,
        countryCode: String,
        country: String,
        duration: String,
        route: String,
        imageUrl: String,
        priceFrom: Int,
        currency: String,
        overview: String,
        highlights: [String],
        sightseeing: [TourSpot],
        itinerary: [TourDay],
        included: [String],
        notIncluded: [String]
    ) {
        self.id = id
        self.title = title
        self.countryCode = countryCode
        self.country = country
        self.duration = duration
        self.route = route
        self.imageUrl = imageUrl
        self.priceFrom = priceFrom
        self.currency = currency
        self.overview = overview
        self.highlights = highlights
        self.sightseeing = sightseeing
        self.itinerary = itinerary
        self.included = included
        self.notIncluded = notIncluded
    }

    /// Maps the summary returned by `ListActiveTourPackages`. The API does not
    /// currently include rich detail sections, so those intentionally remain
    /// empty until a package-detail operation is available.
    static func fromActiveApiJson(_ json: JSON) -> TourPackage {
        TourPackage(
            id: Dart.str(json["id"]) ?? "",
            title: Dart.str(json["name"]) ?? "",
            countryCode: Dart.str(json["flag"]) ?? "",
            country: Dart.str(json["country"]) ?? "",
            duration: Dart.str(json["duration"]) ?? "",
            route: Dart.str(json["route"]) ?? "",
            imageUrl: Dart.str(json["imageUrl"]) ?? "",
            priceFrom: Dart.int(json["fromPrice"]) ?? 0,
            currency: "",
            overview: Dart.str(json["summary"]) ?? "",
            highlights: [],
            sightseeing: [],
            itinerary: [],
            included: [],
            notIncluded: []
        )
    }
}

/// A single sightseeing spot — a name and its photo.
struct TourSpot {
    let name: String
    let imageUrl: String

    init(_ name: String, _ imageUrl: String) {
        self.name = name
        self.imageUrl = imageUrl
    }
}

/// One day of the itinerary — a title and what happens that day.
struct TourDay {
    let title: String
    let description: String

    init(_ title: String, _ description: String) {
        self.title = title
        self.description = description
    }
}
