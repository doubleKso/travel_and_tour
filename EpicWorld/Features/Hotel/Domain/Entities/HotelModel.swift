// Port of lib/features/hotel/domain/entities/hotel_model.dart
import Foundation

/// A hotel returned by the public `ListActiveHotels` catalogue.
struct HotelModel {
    let id: String
    let slug: String
    let name: String
    let location: String // e.g. "Yangon, Myanmar"
    let imageUrl: String
    let rating: Double // 0–5
    let pricePerNight: Int // in `currency`, per night
    let currency: String
    let city: String
    let country: String
    let flagCode: String
    let summary: String?
    let amenities: [String]
    let featured: Bool

    init(
        id: String,
        slug: String = "",
        name: String,
        location: String,
        imageUrl: String,
        rating: Double,
        pricePerNight: Int,
        currency: String,
        city: String = "",
        country: String = "",
        flagCode: String = "",
        summary: String? = nil,
        amenities: [String] = [],
        featured: Bool = false
    ) {
        self.id = id
        self.slug = slug
        self.name = name
        self.location = location
        self.imageUrl = imageUrl
        self.rating = rating
        self.pricePerNight = pricePerNight
        self.currency = currency
        self.city = city
        self.country = country
        self.flagCode = flagCode
        self.summary = summary
        self.amenities = amenities
        self.featured = featured
    }

    static func fromJson(_ json: JSON) -> HotelModel {
        HotelModel(
            // Dart: `json['id'] as String` (a non-string id is a cast error there).
            id: Dart.unwrap(json["id"]) as? String ?? "",
            name: Dart.unwrap(json["name"]) as? String ?? "",
            location: Dart.unwrap(json["location"]) as? String ?? "",
            imageUrl: Dart.unwrap(json["image_url"]) as? String ?? "",
            rating: Dart.double(json["rating"]) ?? 0,
            pricePerNight: Dart.int(json["price_per_night"]) ?? 0,
            currency: Dart.unwrap(json["currency"]) as? String ?? "MMK"
        )
    }

    static func fromActiveApiJson(_ json: JSON) -> HotelModel {
        let city = Dart.str(json["city"]) ?? ""
        let country = Dart.str(json["country"]) ?? ""
        return HotelModel(
            id: Dart.str(json["id"]) ?? "",
            slug: Dart.str(json["slug"]) ?? "",
            name: Dart.str(json["name"]) ?? "",
            location: [city, country].filter { !$0.isEmpty }.joined(separator: ", "),
            imageUrl: imageUrl(json["imageUrl"]),
            rating: Dart.double(json["starRating"]) ?? 0,
            pricePerNight: Dart.int(json["fromPrice"]) ?? 0,
            currency: Dart.str(json["currency"]) ?? "MMK",
            city: city,
            country: country,
            flagCode: Dart.str(json["flag"]) ?? "",
            summary: Dart.str(json["summary"]),
            amenities: amenities(json["amenities"]),
            featured: Dart.bool(json["featured"]) == true
        )
    }

    private static func amenities(_ raw: Any?) -> [String] {
        if let list = Dart.list(raw) {
            return list.map { Dart.interpolate($0) }
        }
        let value = Dart.str(raw)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if value.isEmpty { return [] }
        // `on FormatException`: some older records stored a loosely formatted
        // array. Preserve its items rather than dropping the hotel from the
        // public catalogue.
        if let decoded = try? jsonDecode(value), let list = Dart.list(decoded) {
            return list.map { Dart.interpolate($0) }
        }
        return value
            .replacingOccurrences(of: #"^[\[\s]+|[\]\s]+\z"#, with: "", options: .regularExpression)
            .components(separatedBy: ",")
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\"", with: "")
            }
            .filter { !$0.isEmpty }
    }

    private static let markdownLinkPattern = try! NSRegularExpression(
        pattern: #"^\[(https?://[^\]]+)\]\([^)]*\)\z"#
    )

    private static func imageUrl(_ raw: Any?) -> String {
        let value = Dart.str(raw)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let range = NSRange(value.startIndex..., in: value)
        guard let match = markdownLinkPattern.firstMatch(in: value, range: range),
              let group = Range(match.range(at: 1), in: value) else { return value }
        return String(value[group])
    }
}

/// Places five-star properties at the front while preserving the API order
/// within the five-star and non-five-star groups.
func fiveStarHotelsFirst(_ hotels: [HotelModel]) -> [HotelModel] {
    var fiveStar: [HotelModel] = []
    var otherHotels: [HotelModel] = []
    for hotel in hotels {
        if hotel.rating >= 5 {
            fiveStar.append(hotel)
        } else {
            otherHotels.append(hotel)
        }
    }
    return fiveStar + otherHotels
}
