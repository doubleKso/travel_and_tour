import Foundation

/// Dart's `DateTime`: an instant plus the `isUtc` flag that decides which
/// calendar its fields (`year`, `hour`, `weekday` …) are read in.
///
/// `Foundation.Date` has no such flag, and the booking and ticket logic relies
/// on it — a UTC timestamp from the server reports UTC fields until the Dart
/// code calls `.toLocal()`. Porting to this type keeps that behaviour exact.
///
/// | Dart                                 | Swift                                  |
/// |--------------------------------------|----------------------------------------|
/// | `DateTime(2026, 9, 1, 8)`            | `DateTime(2026, 9, 1, 8)`              |
/// | `DateTime.utc(2026, 9, 1)`           | `DateTime.utc(2026, 9, 1)`             |
/// | `DateTime.now()`                     | `DateTime.now()`                       |
/// | `DateTime.parse(s)` / `tryParse(s)`  | `try DateTime.parse(s)` / `DateTime.tryParse(s)` |
/// | `DateTime.fromMillisecondsSinceEpoch(ms)` | same                              |
/// | `d.add(const Duration(days: 1))`     | `d.add(Duration(days: 1))`             |
/// | `a.difference(b).inMinutes`          | `a.difference(b).inMinutes`            |
/// | `a.isBefore(b)` / `isAfter` / `isAtSameMomentAs` | same                       |
/// | `d.toLocal()` / `d.toUtc()`          | same                                   |
/// | `d.toIso8601String()`                | same                                   |
/// | `d.weekday` (Mon = 1 … Sun = 7)      | same                                   |
/// | `a == b` (same instant *and* `isUtc`)| `a == b`                               |
/// | `a.compareTo(b)`                     | `a.compareTo(b)` or `<`                |
struct DateTime: Hashable, Comparable, CustomStringConvertible {
    /// The instant.
    let date: Date
    /// Whether the fields are read in UTC rather than the device time zone.
    let isUtc: Bool

    // MARK: - Calendars

    static var localCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.autoupdatingCurrent
        return calendar
    }

    static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private var calendar: Calendar { isUtc ? Self.utcCalendar : Self.localCalendar }

    // MARK: - Construction

    init(date: Date, isUtc: Bool = false) {
        self.date = date
        self.isUtc = isUtc
    }

    /// Dart `DateTime(year, [month, day, hour, minute, second, millisecond])`
    /// in local time. Out-of-range fields roll over exactly like Dart
    /// (`DateTime(2026, 9, 0)` is 31 August).
    init(
        _ year: Int,
        _ month: Int = 1,
        _ day: Int = 1,
        _ hour: Int = 0,
        _ minute: Int = 0,
        _ second: Int = 0,
        _ millisecond: Int = 0
    ) {
        self = DateTime.make(year, month, day, hour, minute, second, millisecond, isUtc: false)
    }

    /// Dart `DateTime.utc(...)`.
    static func utc(
        _ year: Int,
        _ month: Int = 1,
        _ day: Int = 1,
        _ hour: Int = 0,
        _ minute: Int = 0,
        _ second: Int = 0,
        _ millisecond: Int = 0
    ) -> DateTime {
        make(year, month, day, hour, minute, second, millisecond, isUtc: true)
    }

    static func now() -> DateTime { DateTime(date: Date(), isUtc: false) }

    static func fromMillisecondsSinceEpoch(_ milliseconds: Int, isUtc: Bool = false) -> DateTime {
        DateTime(date: Date(timeIntervalSince1970: Double(milliseconds) / 1000), isUtc: isUtc)
    }

    private static func make(
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int, _ minute: Int, _ second: Int, _ millisecond: Int,
        isUtc: Bool
    ) -> DateTime {
        let calendar = isUtc ? utcCalendar : localCalendar
        // Normalise month overflow explicitly; the calendar then rolls day,
        // hour, minute and second overflow forward (day 0 is the last day of
        // the previous month, hour 24 the next midnight) exactly as Dart does,
        // and keeps the result a wall-clock time in local mode.
        let monthIndex = month - 1
        let normalizedYear = year + Int((Double(monthIndex) / 12).rounded(.down))
        let normalizedMonth = ((monthIndex % 12) + 12) % 12 + 1
        var components = DateComponents()
        components.year = normalizedYear
        components.month = normalizedMonth
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        let base = calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
        return DateTime(date: base.addingTimeInterval(Double(millisecond) / 1000), isUtc: isUtc)
    }

    // MARK: - Fields

    /// Whole milliseconds since the epoch. Every field is derived from this
    /// one integer so `second` and `millisecond` can never disagree through
    /// floating-point drift (Dart stores an integer too).
    private var epochMilliseconds: Int { Int((date.timeIntervalSince1970 * 1000).rounded()) }

    /// The instant truncated to its whole second, for calendar fields.
    private var wholeSecond: Date {
        let ms = epochMilliseconds
        let floorSeconds = ms >= 0 ? ms / 1000 : -((-ms + 999) / 1000)
        return Date(timeIntervalSince1970: Double(floorSeconds))
    }

    private func field(_ component: Calendar.Component) -> Int {
        calendar.component(component, from: wholeSecond)
    }

    var year: Int { field(.year) }
    var month: Int { field(.month) }
    var day: Int { field(.day) }
    var hour: Int { field(.hour) }
    var minute: Int { field(.minute) }
    var second: Int { field(.second) }

    var millisecond: Int {
        ((epochMilliseconds % 1000) + 1000) % 1000
    }

    /// Monday = 1 … Sunday = 7, as in Dart.
    var weekday: Int {
        let gregorian = field(.weekday) // Sunday = 1 … Saturday = 7
        return gregorian == 1 ? 7 : gregorian - 1
    }

    var millisecondsSinceEpoch: Int { Int((date.timeIntervalSince1970 * 1000).rounded()) }

    var timeZoneOffset: Duration {
        isUtc ? .zero : Duration(seconds: TimeZone.autoupdatingCurrent.secondsFromGMT(for: date))
    }

    // MARK: - Arithmetic

    func add(_ duration: Duration) -> DateTime {
        DateTime(date: date.addingTimeInterval(duration.timeInterval), isUtc: isUtc)
    }

    func subtract(_ duration: Duration) -> DateTime {
        DateTime(date: date.addingTimeInterval(-duration.timeInterval), isUtc: isUtc)
    }

    /// `self - other`, like Dart's `difference`.
    func difference(_ other: DateTime) -> Duration {
        let ms = ((date.timeIntervalSince1970 - other.date.timeIntervalSince1970) * 1000).rounded()
        return .milliseconds(Int64(ms))
    }

    func isBefore(_ other: DateTime) -> Bool { date < other.date }
    func isAfter(_ other: DateTime) -> Bool { date > other.date }
    func isAtSameMomentAs(_ other: DateTime) -> Bool { date == other.date }

    func compareTo(_ other: DateTime) -> Int {
        date < other.date ? -1 : (date > other.date ? 1 : 0)
    }

    static func < (lhs: DateTime, rhs: DateTime) -> Bool { lhs.date < rhs.date }

    func toLocal() -> DateTime { isUtc ? DateTime(date: date, isUtc: false) : self }
    func toUtc() -> DateTime { isUtc ? self : DateTime(date: date, isUtc: true) }

    /// `DateTime(year, month, day)` of this value — the common "date only" idiom.
    var dateOnly: DateTime {
        isUtc ? .utc(year, month, day) : DateTime(year, month, day)
    }

    /// Dart's `copyWith` (Dart 2.19+).
    func copyWith(
        year: Int? = nil, month: Int? = nil, day: Int? = nil,
        hour: Int? = nil, minute: Int? = nil, second: Int? = nil, millisecond: Int? = nil
    ) -> DateTime {
        DateTime.make(
            year ?? self.year, month ?? self.month, day ?? self.day,
            hour ?? self.hour, minute ?? self.minute, second ?? self.second,
            millisecond ?? self.millisecond, isUtc: isUtc
        )
    }

    // MARK: - Parsing

    private static let parsePattern = try! NSRegularExpression(
        pattern: #"^([+-]?\d{4,6})-?(\d\d)-?(\d\d)(?:[ T](\d\d)(?::?(\d\d)(?::?(\d\d)(?:[.,](\d+))?)?)?( ?[zZ]| ?([-+])(\d\d)(?::?(\d\d))?)?)?$"#
    )

    /// Dart `DateTime.parse`. A value with `Z` or an offset becomes a UTC
    /// `DateTime`; one without is local.
    static func parse(_ formattedString: String) throws -> DateTime {
        guard let value = tryParse(formattedString) else {
            throw FormatException("Invalid date format\n\(formattedString)")
        }
        return value
    }

    /// Dart `DateTime.tryParse`.
    static func tryParse(_ formattedString: String) -> DateTime? {
        let text = formattedString
        let range = NSRange(text.startIndex..., in: text)
        guard let match = parsePattern.firstMatch(in: text, range: range) else { return nil }

        func group(_ index: Int) -> String? {
            let r = match.range(at: index)
            guard r.location != NSNotFound, let swiftRange = Range(r, in: text) else { return nil }
            return String(text[swiftRange])
        }

        guard let year = group(1).flatMap({ Int($0) }),
              let month = group(2).flatMap({ Int($0) }),
              let day = group(3).flatMap({ Int($0) }) else { return nil }
        let hour = group(4).flatMap { Int($0) } ?? 0
        let minute = group(5).flatMap { Int($0) } ?? 0
        let second = group(6).flatMap { Int($0) } ?? 0
        // `Date` keeps millisecond precision here; digits past the third are
        // dropped, matching what Dart's `millisecond` getter reports.
        var millisecond = 0
        if let fraction = group(7) {
            millisecond = Int(String((fraction + "000").prefix(3))) ?? 0
        }

        if group(8) != nil {
            var value = make(year, month, day, hour, minute, second, millisecond, isUtc: true)
            if let sign = group(9) {
                let offsetHours = group(10).flatMap { Int($0) } ?? 0
                let offsetMinutes = group(11).flatMap { Int($0) } ?? 0
                let offset = (offsetHours * 60 + offsetMinutes) * (sign == "-" ? -1 : 1)
                value = value.subtract(Duration(minutes: offset))
            }
            return value
        }
        return make(year, month, day, hour, minute, second, millisecond, isUtc: false)
    }

    // MARK: - Formatting

    private static func pad(_ value: Int, _ width: Int) -> String {
        let digits = String(abs(value))
        let padded = String(repeating: "0", count: max(0, width - digits.count)) + digits
        return value < 0 ? "-" + padded : padded
    }

    private var yearString: String {
        let y = year
        if (0...9999).contains(y) { return Self.pad(y, 4) }
        return (y < 0 ? "-" : "+") + Self.pad(abs(y), 6)
    }

    /// Dart `toIso8601String()`: `2026-09-02T08:00:00.000` (`Z` when UTC).
    func toIso8601String() -> String {
        "\(yearString)-\(Self.pad(month, 2))-\(Self.pad(day, 2))T"
            + "\(Self.pad(hour, 2)):\(Self.pad(minute, 2)):\(Self.pad(second, 2)).\(Self.pad(millisecond, 3))"
            + (isUtc ? "Z" : "")
    }

    /// Dart `toString()`: `2026-09-02 08:00:00.000` (`Z` when UTC).
    var description: String {
        "\(yearString)-\(Self.pad(month, 2))-\(Self.pad(day, 2)) "
            + "\(Self.pad(hour, 2)):\(Self.pad(minute, 2)):\(Self.pad(second, 2)).\(Self.pad(millisecond, 3))"
            + (isUtc ? "Z" : "")
    }
}

/// Dart's `Duration` API on Swift's `Duration`, so ported code reads the same
/// and still works with `Task.sleep(for:)`.
///
/// | Dart                                   | Swift                           |
/// |----------------------------------------|---------------------------------|
/// | `const Duration(minutes: 5)`           | `Duration(minutes: 5)`          |
/// | `d.inMinutes` / `inHours` / `inDays` / `inSeconds` / `inMilliseconds` | same |
/// | `d.isNegative`                         | same                            |
/// | `d.abs()`                              | same                            |
/// | `Duration.zero`                        | `.zero`                         |
/// | `await Future.delayed(d)`              | `try? await Task.sleep(for: d)` |
extension Duration {
    init(
        days: Int = 0,
        hours: Int = 0,
        minutes: Int = 0,
        seconds: Int = 0,
        milliseconds: Int = 0,
        microseconds: Int = 0
    ) {
        let totalMicros = Int64(days) * 86_400_000_000
            + Int64(hours) * 3_600_000_000
            + Int64(minutes) * 60_000_000
            + Int64(seconds) * 1_000_000
            + Int64(milliseconds) * 1_000
            + Int64(microseconds)
        self = .microseconds(totalMicros)
    }

    var inMicroseconds: Int {
        let parts = components
        return Int(parts.seconds) * 1_000_000 + Int(parts.attoseconds / 1_000_000_000_000)
    }

    var inMilliseconds: Int { inMicroseconds / 1_000 }
    var inSeconds: Int { inMicroseconds / 1_000_000 }
    var inMinutes: Int { inMicroseconds / 60_000_000 }
    var inHours: Int { inMicroseconds / 3_600_000_000 }
    var inDays: Int { inMicroseconds / 86_400_000_000 }

    var isNegative: Bool { self < .zero }

    func abs() -> Duration { isNegative ? .zero - self : self }

    /// Seconds as a `TimeInterval`, for UIKit/Foundation APIs.
    var timeInterval: TimeInterval {
        let parts = components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }
}
