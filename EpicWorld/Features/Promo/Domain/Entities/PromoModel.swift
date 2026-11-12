// Port of lib/features/promo/domain/entities/promo_model.dart

import Foundation

/// A promotional card shown in the home hero carousel (discounted airlines /
/// bus lines). In production these come from a CMS / promotions endpoint.
struct PromoModel: Hashable {
    let id: String
    let title: String
    let subtitle: String
    let discountLabel: String // e.g. "Up to 30% OFF"
    let imageUrl: String
    let partnerName: String // airline or bus operator
    let type: PromoType

    init(
        id: String,
        title: String,
        subtitle: String,
        discountLabel: String,
        imageUrl: String,
        partnerName: String,
        type: PromoType
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.discountLabel = discountLabel
        self.imageUrl = imageUrl
        self.partnerName = partnerName
        self.type = type
    }

    static func fromJson(_ json: JSON) -> PromoModel {
        PromoModel(
            // Dart `json['id'] as String` / `json['title'] as String`: a value
            // that is not a string falls back to empty instead of throwing.
            id: (Dart.unwrap(json["id"]) as? String) ?? "",
            title: (Dart.unwrap(json["title"]) as? String) ?? "",
            subtitle: (Dart.unwrap(json["subtitle"]) as? String) ?? "",
            discountLabel: (Dart.unwrap(json["discount_label"]) as? String) ?? "",
            imageUrl: (Dart.unwrap(json["image_url"]) as? String) ?? "",
            partnerName: (Dart.unwrap(json["partner_name"]) as? String) ?? "",
            type: PromoType.values.first(where: { $0.name == Dart.str(json["type"]) }) ?? .flight
        )
    }
}

enum PromoType: String, CaseIterable, DartEnum {
    case flight, bus
}
