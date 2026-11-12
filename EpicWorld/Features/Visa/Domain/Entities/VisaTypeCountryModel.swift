// Port of lib/features/visa/domain/entities/visa_type_country_model.dart

import Foundation

/// Country availability returned by `ListPublishedVisaTypeCountries`.
struct VisaTypeCountryModel {
    let countryId: String

    init(countryId: String) {
        self.countryId = countryId
    }

    static func fromJson(_ json: JSON) -> VisaTypeCountryModel {
        VisaTypeCountryModel(countryId: Dart.str(json["countryId"]) ?? "")
    }
}

/// Keeps the Visa screen limited to active countries which currently have at
/// least one published visa type. IDs are normalized because catalogue values
/// can differ in whitespace or UUID casing between environments.
func publishedVisaCountries(
    _ countries: [VisaCountryModel],
    _ visaTypes: [VisaTypeCountryModel]
) -> [VisaCountryModel] {
    let publishedCountryIds = Set(
        visaTypes
            .map { $0.countryId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    )
    return countries.filter { country in
        publishedCountryIds.contains(country.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}
