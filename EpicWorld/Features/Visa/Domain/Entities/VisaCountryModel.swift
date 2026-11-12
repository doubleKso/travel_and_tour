// Port of lib/features/visa/domain/entities/visa_country_model.dart

import Foundation

/// Public visa destination returned by `ListActiveVisaCountries`.
struct VisaCountryModel {
    let id: String
    let slug: String
    let name: String
    let flagCode: String
    let flagUrl: String
    let featured: Bool

    init(
        id: String,
        slug: String,
        name: String,
        flagCode: String,
        flagUrl: String,
        featured: Bool
    ) {
        self.id = id
        self.slug = slug
        self.name = name
        self.flagCode = flagCode
        self.flagUrl = flagUrl
        self.featured = featured
    }

    static func fromJson(_ json: JSON) -> VisaCountryModel {
        VisaCountryModel(
            id: Dart.str(json["id"]) ?? "",
            slug: Dart.str(json["slug"]) ?? "",
            name: Dart.str(json["name"]) ?? "",
            flagCode: Dart.str(json["flagCode"]) ?? "",
            flagUrl: Dart.str(json["flagUrl"]) ?? "",
            featured: Dart.bool(json["featured"]) == true
        )
    }
}
