// Port of lib/features/booking/domain/entities/nrc_models.dart

import Foundation

/// A Myanmar NRC state/division code returned by `dcExec:ListNrcCodes`.
struct NrcCode: Hashable {
    let code: String
    let nameEn: String
    let nameMm: String

    init(code: String, nameEn: String, nameMm: String) {
        self.code = code
        self.nameEn = nameEn
        self.nameMm = nameMm
    }

    static func fromJson(_ json: JSON) -> NrcCode {
        NrcCode(
            code: Dart.str(json["code"]) ?? "",
            nameEn: Dart.str(json["nameEn"]) ?? "",
            nameMm: Dart.str(json["nameMm"]) ?? ""
        )
    }

    /// The backend sends code values as strings, so a lexical sort would place
    /// `10` immediately after `1`. Keep the selector in normal numeric order.
    ///
    /// Dart comparator (negative / zero / positive); sort with
    /// `codes.sort { NrcCode.compareByCode($0, $1) < 0 }`.
    static func compareByCode(_ first: NrcCode, _ second: NrcCode) -> Int {
        let firstNumber = Dart.parseInt(first.code)
        let secondNumber = Dart.parseInt(second.code)
        if let firstNumber, let secondNumber {
            return firstNumber < secondNumber ? -1 : (firstNumber > secondNumber ? 1 : 0)
        }
        if firstNumber != nil { return -1 }
        if secondNumber != nil { return 1 }
        return first.code < second.code ? -1 : (first.code > second.code ? 1 : 0)
    }
}

/// A township valid for a particular NRC code, as returned by
/// `dcExec:ListNrcTownshipsByCode`.
struct NrcTownship: Hashable {
    let id: String
    let short: String
    let shortEn: String
    let cityName: String

    init(id: String, short: String, shortEn: String, cityName: String) {
        self.id = id
        self.short = short
        self.shortEn = shortEn
        self.cityName = cityName
    }

    static func fromJson(_ json: JSON) -> NrcTownship {
        NrcTownship(
            id: Dart.str(json["id"]) ?? "",
            short: Dart.str(json["short"]) ?? "",
            shortEn: Dart.str(json["shortEn"]) ?? "",
            cityName: Dart.str(json["cityName"]) ?? ""
        )
    }
}
