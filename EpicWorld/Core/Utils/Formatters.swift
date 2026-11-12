import Foundation

/// Small formatting helpers used across screens — the port of
/// lib/core/utils/formatters.dart. Centralized so currency and date formats
/// stay consistent.
enum Formatters {
    private static let currency = NumberFormat.decimalPattern()

    /// e.g. 125000 -> "125,000 MMK"
    static func price(_ amount: Double, _ currencyCode: String = "MMK") -> String {
        "\(currency.format(Int(amount.rounded(.toNearestOrAwayFromZero)))) \(currencyCode)"
    }

    /// Grouped number without a currency suffix, e.g. 690000 -> "690,000".
    static func grouped(_ amount: Double) -> String { currency.format(amount) }
    static func grouped(_ amount: Int) -> String { currency.format(amount) }

    /// e.g. "06:30"
    static func time(_ dt: DateTime) -> String { DateFormat.Hm().format(dt) }

    /// e.g. "09:00 am"
    static func time12(_ dt: DateTime) -> String {
        DateFormat("hh:mm a").format(dt).lowercased()
    }

    /// e.g. "9:00 A.M.". Used for the customer-facing e-ticket where a
    /// 12-hour time must be unambiguous in the exported document.
    static func eTicketTime(_ dt: DateTime) -> String {
        "\(DateFormat("h:mm").format(dt)) \(dt.hour < 12 ? "A.M." : "P.M.")"
    }

    /// Converts an API schedule time such as `14:05` or `7:00 PM` to the
    /// 12-hour clock used by flight cards. Unknown formats are preserved
    /// rather than replaced with an invented time.
    static func scheduleTime12(_ input: String) -> String {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return "" }
        guard let regex = try? NSRegularExpression(
            pattern: #"^(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM)?$"#,
            options: [.caseInsensitive]
        ), let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) else {
            return raw
        }
        func group(_ i: Int) -> String? {
            guard let r = Range(match.range(at: i), in: raw) else { return nil }
            return String(raw[r])
        }
        guard var hour = group(1).flatMap({ Int($0) }),
              let minute = group(2).flatMap({ Int($0) }) else { return raw }
        let period = group(3)?.uppercased()
        if minute > 59 || (period == nil && hour > 23) { return raw }
        if let period {
            if hour < 1 || hour > 12 { return raw }
            if period == "PM" && hour != 12 { hour += 12 }
            if period == "AM" && hour == 12 { hour = 0 }
        }
        return time12(DateTime(2000, 1, 1, hour, minute))
    }

    /// e.g. "Mon, 12 Jun"
    static func shortDate(_ dt: DateTime) -> String { DateFormat("EEE, d MMM").format(dt) }

    /// e.g. "12 Jun 2026"
    static func fullDate(_ dt: DateTime) -> String { DateFormat("d MMM y").format(dt) }

    /// e.g. "12/06/2026" — numeric dd/mm/yyyy, matching the date-of-birth field.
    static func numericDate(_ dt: DateTime) -> String { DateFormat("dd/MM/yyyy").format(dt) }

    /// e.g. "12/06/26" — numeric dd/mm/yy (2-digit year), used by the V2 home
    /// Departure / Return date fields.
    static func numericDateShort(_ dt: DateTime) -> String { DateFormat("dd/MM/yy").format(dt) }

    /// Parse a user-typed date, accepting a few common formats (matches the
    /// `fullDate` display plus numeric forms). Returns nil if none match.
    static func tryParseDate(_ input: String) -> DateTime? {
        let s = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return nil }
        for pattern in ["d MMM y", "d/M/y", "d-M-y", "y-M-d"] {
            if let parsed = DateFormat(pattern).tryParseStrict(s) { return parsed }
        }
        return nil
    }

    /// e.g. "July 2026" — used for the month filter.
    static func monthYear(_ dt: DateTime) -> String { DateFormat("MMMM y").format(dt) }

    /// e.g. Duration(1h 25m) -> "1h 25m"
    static func duration(_ d: Duration) -> String {
        let h = d.inHours
        let m = d.inMinutes % 60
        if h == 0 { return "\(m)m" }
        return "\(h)h \(m)m"
    }

    /// Countdown text for the active-ticket reminder, e.g. "2d 4h 12m".
    static func countdown(_ d: Duration) -> String {
        if d.isNegative { return "Departed" }
        let days = d.inDays
        let hours = d.inHours % 24
        let mins = d.inMinutes % 60
        if days > 0 { return "\(days)d \(hours)h \(mins)m" }
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins)m"
    }
}
