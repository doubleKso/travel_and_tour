// Port of lib/features/booking/domain/entities/traveller_age_rules.dart

import Foundation

/// Age boundaries used when validating traveller categories.
enum TravellerAgeRules {
    static let adultThresholdYears = 12

    /// The latest date of birth that is strictly older than 12 on `travelDate`.
    ///
    /// Someone born exactly 12 years before departure is not yet above the
    /// threshold, so the accepted boundary is one calendar day earlier.
    static func latestAdultDateOfBirth(_ travelDate: DateTime) -> DateTime {
        let date = dateOnly(travelDate)
        let twelveYearsEarlier = sameDayInYear(date, date.year - adultThresholdYears)
        return twelveYearsEarlier.subtract(Duration(days: 1))
    }

    static func isOlderThan12(dateOfBirth: DateTime, travelDate: DateTime) -> Bool {
        !dateOnly(dateOfBirth).isAfter(latestAdultDateOfBirth(travelDate))
    }

    private static func dateOnly(_ date: DateTime) -> DateTime {
        DateTime(date.year, date.month, date.day)
    }

    /// Keeps 29 February inside the target year by clamping to its final valid
    /// day when necessary.
    private static func sameDayInYear(_ date: DateTime, _ year: Int) -> DateTime {
        let lastDayOfMonth = DateTime(year, date.month + 1, 0).day
        let day = min(max(date.day, 1), lastDayOfMonth)
        return DateTime(year, date.month, day)
    }
}
