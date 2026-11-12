// Port of lib/features/visa/domain/entities/visa_country_detail_model.dart

import Foundation

/// Full destination profile returned by `dcExec:GetVisaCountryBySlug`.
///
/// Richer than the catalogue `VisaCountryModel` used by the Visa screen grid:
/// it adds the official name, the intro copy, and the artwork (emblem, globe)
/// the country screen is built around.
struct VisaCountryDetail {
    let id: String
    let slug: String
    let name: String
    let officialName: String
    let flagCode: String
    let flagUrl: String
    let emblemUrl: String
    let globeUrl: String
    let intro: String

    init(
        id: String,
        slug: String,
        name: String,
        officialName: String,
        flagCode: String,
        flagUrl: String,
        emblemUrl: String,
        globeUrl: String,
        intro: String
    ) {
        self.id = id
        self.slug = slug
        self.name = name
        self.officialName = officialName
        self.flagCode = flagCode
        self.flagUrl = flagUrl
        self.emblemUrl = emblemUrl
        self.globeUrl = globeUrl
        self.intro = intro
    }

    static func fromJson(_ json: JSON) -> VisaCountryDetail {
        VisaCountryDetail(
            id: Dart.str(json["id"]) ?? "",
            slug: Dart.str(json["slug"]) ?? "",
            name: Dart.str(json["name"]) ?? "",
            officialName: Dart.str(json["officialName"]) ?? "",
            flagCode: Dart.str(json["flagCode"]) ?? "",
            flagUrl: Dart.str(json["flagUrl"]) ?? "",
            emblemUrl: Dart.str(json["emblemUrl"]) ?? "",
            globeUrl: Dart.str(json["globeUrl"]) ?? "",
            intro: Dart.str(json["intro"]) ?? ""
        )
    }

    /// Headline for the country screen — the official name when the catalogue
    /// carries one ("People's Republic of China"), else the short name.
    var headline: String {
        let official = officialName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !official.isEmpty ? official : name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
