// Port of lib/features/booking/domain/entities/fare_option_model.dart

import Foundation

/// One fare that can be chosen for a flight returned by `searchFlights`.
///
/// The search service returns these nested under an itinerary. Keeping them
/// typed means the chosen price and fare basis survive into `holdFlight`.
struct FareOptionModel: Hashable {
    let id: String
    let brand: String
    let basis: String?
    let bookingClass: String?
    let travelClass: TravelClass
    /// Total for every passenger in the search.
    let price: Double

    /// `price` spread over the passengers, as the search service quotes it.
    /// `holdFlight` checks its `expectedPrice` against this figure.
    let pricePerPax: Double?
    let currency: String
    let baggageKg: Int?
    let refundable: Bool
    let selected: Bool

    init(
        id: String,
        brand: String,
        basis: String? = nil,
        bookingClass: String? = nil,
        travelClass: TravelClass,
        price: Double,
        pricePerPax: Double? = nil,
        currency: String,
        baggageKg: Int? = nil,
        refundable: Bool = false,
        selected: Bool = false
    ) {
        self.id = id
        self.brand = brand
        self.basis = basis
        self.bookingClass = bookingClass
        self.travelClass = travelClass
        self.price = price
        self.pricePerPax = pricePerPax
        self.currency = currency
        self.baggageKg = baggageKg
        self.refundable = refundable
        self.selected = selected
    }
}
