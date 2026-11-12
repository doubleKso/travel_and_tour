// Port of lib/features/visa/domain/entities/visa_free_country.dart

import Foundation

/// Destination a Myanmar passport holder can enter without applying for a
/// visa first. Shown in the "Visa-Free Countries" half of the Visa screen.
struct VisaFreeCountry {
    let name: String
    let flagCode: String

    init(name: String, flagCode: String) {
        self.name = name
        self.flagCode = flagCode
    }

    /// Flags are not bundled — the shared CDN serves them by ISO 3166-1 code.
    var flagUrl: String {
        "https://flagcdn.com/w160/\(flagCode.lowercased()).png"
    }
}

/// The visa-free list mirrors the Epic World website. It is curated rather
/// than fetched because the catalogue API only exposes destinations the visa
/// desk processes applications for; swap this for an operation once the
/// backend publishes one.
let visaFreeCountries: [VisaFreeCountry] = [
    VisaFreeCountry(name: "Brunei", flagCode: "BN"),
    VisaFreeCountry(name: "Indonesia", flagCode: "ID"),
    VisaFreeCountry(name: "Philippines", flagCode: "PH"),
    VisaFreeCountry(name: "Vietnam", flagCode: "VN"),
    VisaFreeCountry(name: "Cook Islands", flagCode: "CK"),
    VisaFreeCountry(name: "Laos", flagCode: "LA"),
    VisaFreeCountry(name: "Singapore", flagCode: "SG"),
    VisaFreeCountry(name: "Dominica", flagCode: "DM"),
    VisaFreeCountry(name: "Micronesia", flagCode: "FM"),
    VisaFreeCountry(name: "Saint Vincent & the Grenadines", flagCode: "VC"),
    VisaFreeCountry(name: "Haiti", flagCode: "HT"),
    VisaFreeCountry(name: "Montserrat", flagCode: "MS"),
    VisaFreeCountry(name: "Thailand", flagCode: "TH"),
]
