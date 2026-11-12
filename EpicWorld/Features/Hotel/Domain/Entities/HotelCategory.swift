// Port of lib/features/hotel/domain/entities/hotel_category.dart
//
// Data for the Hotel Booking feature — the hotel categories shown on the Hotel
// screen and the rich content each one's detail page renders.
//
// Kept self-contained in the hotel feature folder (like the tour packages and
// the visa screen's inline data): it's presentation content, not something the
// booking API serves yet. Swap `HotelCategory.all` for a repository call when
// the hotels endpoint lands.
import Foundation

/// One hotel category — enough content to render both the summary card on the
/// Hotel screen and the full detail page (overview, amenities, what's included,
/// who it's ideal for, and a photo gallery).
struct HotelCategory {
    let id: String

    /// Card / detail headline, e.g. "Business Hotels".
    let title: String

    /// One-line card description shown under the title.
    let tagline: String

    /// Hero / card background photo.
    let imageUrl: String

    /// Category glyph, shown in the frosted badge on the card and the hero.
    let icon: IconData

    /// Long-form intro paragraph for the Overview section.
    let overview: String

    /// Amenity chips (icon + label) shown as a grid on the detail page.
    let amenities: [HotelAmenity]

    /// Bullet features, each rendered as a ticked card.
    let features: [String]

    /// "Ideal for" audience bullets.
    let idealFor: [String]

    /// Gallery photos shown as a horizontal image strip.
    let gallery: [String]

    /// "Starting from" nightly price and its currency.
    let priceFrom: Int
    let currency: String

    init(
        id: String,
        title: String,
        tagline: String,
        imageUrl: String,
        icon: IconData,
        overview: String,
        amenities: [HotelAmenity],
        features: [String],
        idealFor: [String],
        gallery: [String],
        priceFrom: Int,
        currency: String
    ) {
        self.id = id
        self.title = title
        self.tagline = tagline
        self.imageUrl = imageUrl
        self.icon = icon
        self.overview = overview
        self.amenities = amenities
        self.features = features
        self.idealFor = idealFor
        self.gallery = gallery
        self.priceFrom = priceFrom
        self.currency = currency
    }
}

/// A single amenity — a custom SVG glyph and its label.
struct HotelAmenity {
    /// Path to the amenity's custom SVG icon (rendered tinted, like the
    /// department icons elsewhere in the app).
    let asset: String
    let label: String

    init(_ asset: String, _ label: String) {
        self.asset = asset
        self.label = label
    }
}
