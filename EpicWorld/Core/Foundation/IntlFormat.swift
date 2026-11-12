import Foundation

/// `package:intl`'s `DateFormat`, over `DateFormatter`.
///
/// intl and ICU share the pattern letters this app uses (`y M d E H h m s a`),
/// so patterns port verbatim. The Flutter app never sets `Intl.defaultLocale`
/// (easy_localization does not either), so every intl format renders in
/// English with Latin digits whatever the UI language — the default locale
/// here is `en_US_POSIX` for the same reason.
///
/// A `DateTime` is formatted in its own calendar: UTC fields for a UTC value,
/// device-local fields otherwise — the same as intl.
///
/// ```swift
/// DateFormat("EEE, d MMM").format(dt)      // Dart: DateFormat('EEE, d MMM').format(dt)
/// DateFormat.Hm().format(dt)               // Dart: DateFormat.Hm().format(dt)
/// try DateFormat("d/M/y").parseStrict(s)   // Dart: DateFormat('d/M/y').parseStrict(s)
/// ```
final class DateFormat {
    let pattern: String
    private let formatter: DateFormatter

    init(_ pattern: String, _ locale: String? = nil) {
        self.pattern = pattern
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: locale ?? "en_US_POSIX")
        formatter.dateFormat = pattern
        self.formatter = formatter
    }

    // Named constructors used by the Flutter code base.
    // swiftlint:disable identifier_name
    static func Hm() -> DateFormat { DateFormat("HH:mm") }
    static func Hms() -> DateFormat { DateFormat("HH:mm:ss") }
    static func jm() -> DateFormat { DateFormat("h:mm a") }
    static func y() -> DateFormat { DateFormat("y") }
    static func yMd() -> DateFormat { DateFormat("M/d/y") }
    static func yMMMd() -> DateFormat { DateFormat("MMM d, y") }
    static func yMMMMd() -> DateFormat { DateFormat("MMMM d, y") }
    static func MMMd() -> DateFormat { DateFormat("MMM d") }
    static func MMMEd() -> DateFormat { DateFormat("EEE, MMM d") }
    static func E() -> DateFormat { DateFormat("EEE") }
    static func EEEE() -> DateFormat { DateFormat("EEEE") }
    // swiftlint:enable identifier_name

    func format(_ dateTime: DateTime) -> String {
        formatter.timeZone = dateTime.isUtc ? TimeZone(secondsFromGMT: 0) : TimeZone.autoupdatingCurrent
        return formatter.string(from: dateTime.date)
    }

    /// intl `parse`: lenient, local time.
    func parse(_ input: String) throws -> DateTime {
        try parse(input, strict: false)
    }

    /// intl `parseStrict`: the whole input must match the pattern and every
    /// field must be in range.
    func parseStrict(_ input: String) throws -> DateTime {
        try parse(input, strict: true)
    }

    func tryParse(_ input: String) -> DateTime? { try? parse(input) }
    func tryParseStrict(_ input: String) -> DateTime? { try? parseStrict(input) }

    private func parse(_ input: String, strict: Bool) throws -> DateTime {
        formatter.timeZone = TimeZone.autoupdatingCurrent
        formatter.isLenient = !strict
        defer { formatter.isLenient = false }
        // A non-lenient DateFormatter rejects trailing text and out-of-range
        // fields, which is what intl's strict parse checks for.
        guard let date = formatter.date(from: input) else {
            throw FormatException("Trying to read \(pattern) from \(input)")
        }
        return DateTime(date: date, isUtc: false)
    }
}

/// `package:intl`'s `NumberFormat`, over `NumberFormatter`, with intl's
/// defaults: `en_US` symbols and half-up rounding.
///
/// ```swift
/// NumberFormat.decimalPattern().format(125000)   // "125,000"
/// NumberFormat("#,##0.00").format(12.5)          // "12.50"
/// ```
final class NumberFormat {
    private let formatter: NumberFormatter

    init(_ pattern: String? = nil, _ locale: String? = nil) {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: locale ?? "en_US")
        formatter.roundingMode = .halfUp
        if let pattern {
            formatter.positiveFormat = pattern
            formatter.negativeFormat = "-" + pattern
        } else {
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 3
        }
        self.formatter = formatter
    }

    /// intl `NumberFormat.decimalPattern()`: grouped, up to 3 decimals.
    static func decimalPattern(_ locale: String? = nil) -> NumberFormat {
        NumberFormat(nil, locale)
    }

    func format(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    func format(_ value: Int) -> String {
        formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    func parse(_ text: String) throws -> Double {
        guard let number = formatter.number(from: text) else {
            throw FormatException("Could not parse \(text)")
        }
        return number.doubleValue
    }
}
