// Port of lib/features/booking/domain/entities/booking_enums.dart
// Shared enums for the booking domain (flight + bus).

import Foundation

/// What the user is booking.
enum TravelMode: String, CaseIterable, DartEnum {
    case flight, bus
}

/// Domestic vs international scope (bus is domestic-only per the brief).
enum TravelScope: String, CaseIterable, DartEnum {
    case domestic, international
}

/// Trip type toggled on the search form.
enum TripType: String, CaseIterable, DartEnum {
    case oneWay, roundTrip
}

/// Traveller nationality — drives pricing tiers / visa requirements later.
enum Nationality: String, CaseIterable, DartEnum {
    case myanmar, foreigner
}

/// Dart `extension NationalityLabel on Nationality`.
extension Nationality {
    var label: String {
        switch self {
        case .myanmar: return "Myanmar"
        case .foreigner: return "Other"
        }
    }

    /// Value sent as `nationality` on the `searchFlights` request.
    var code: String {
        switch self {
        case .myanmar: return "MM"
        case .foreigner: return "OTHER"
        }
    }
}

/// Cabin / seat class used in filters.
enum TravelClass: String, CaseIterable, DartEnum {
    case economy, business
}

/// Dart `extension TravelClassLabel on TravelClass`.
extension TravelClass {
    var label: String {
        switch self {
        case .economy: return "Economy"
        // TravelClass.premiumEconomy => 'Premium',
        case .business: return "Business"
        // TravelClass.first => 'First',
        }
    }
}

/// Stages of the checkout journey, used by the progress tracker widget.
/// The order of these values IS the visual order of the tracker.
enum BookingStage: String, CaseIterable, DartEnum {
    case search, detail, confirmation, payment, completed
}

/// Dart `extension BookingStageLabel on BookingStage`.
extension BookingStage {
    var label: String {
        switch self {
        case .search: return "Search"
        case .detail: return "Detail"
        case .confirmation: return "Confirm"
        case .payment: return "Payment"
        case .completed: return "Completed"
        }
    }
}
