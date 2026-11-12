// Port of lib/features/booking/domain/repositories/booking_repository.dart

import Foundation

/// Search-side contract for the booking feature.
protocol BookingRepository: AnyObject {
    /// Airports / terminals offered in the From–To picker.
    func getLocations() async -> AppResult<[LocationModel]>

    /// Submits the user's criteria to the live Firebase flight-search callable.
    func submitFlightSearch(_ request: FlightSearchRequest) async -> AppResult<[TripOptionModel]>

    /// Creates a held booking and returns its reference and PNR.
    func holdFlight(_ request: FlightHoldRequest) async -> AppResult<FlightHoldResponse>

    /// Submits an enquiry for an airline that does not support in-app booking.
    func createServiceEnquiry(_ request: ServiceEnquiryRequest) async -> AppResult<ServiceEnquirySubmission>

    /// Retrieves enquiries created by the current customer.
    func getMyServiceEnquiries(userId: String, email: String) async -> AppResult<[ServiceEnquiryModel]>

    /// Trips for one leg on one date.
    func searchTrips(
        mode: TravelMode,
        date: DateTime,
        from: LocationModel,
        to: LocationModel
    ) async -> AppResult<[TripOptionModel]>

    /// Cheapest fare per day across a window centred on `around` — what the date
    /// strip shows under each chip. Keyed by `DateTime(y, m, d)`.
    func getDailyMinPrices(
        mode: TravelMode,
        from: LocationModel,
        to: LocationModel,
        around: DateTime,
        windowDays: Int
    ) async -> AppResult<[DateTime: Double]>
}

extension BookingRepository {
    /// Dart's `int windowDays = 15` default (protocol requirements cannot carry one).
    func getDailyMinPrices(
        mode: TravelMode,
        from: LocationModel,
        to: LocationModel,
        around: DateTime
    ) async -> AppResult<[DateTime: Double]> {
        await getDailyMinPrices(mode: mode, from: from, to: to, around: around, windowDays: 15)
    }
}
