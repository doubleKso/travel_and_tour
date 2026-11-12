// Port of lib/features/booking/presentation/bloc/flight_booking_event.dart

import Foundation

/// Everything that can happen to the search → detail → payment → completed
/// flow. Widgets `add` these; only `FlightBookingBloc` turns them into a new
/// `FlightBookingState`.
///
/// Named for what happened (`tripTypeChanged`), not for what the bloc should do,
/// so the bloc stays the only place that decides how state reacts.
///
/// Dart's sealed class + one final class per event becomes one case per event
/// (PORTING_GUIDE §5): positional constructor parameters are unlabeled
/// associated values, named parameters keep their Dart labels and defaults.
enum FlightBookingEvent {
    // ---- Search criteria ---------------------------------------------------

    /// Flight or bus. Bus is domestic-only, so picking it also forces the scope.
    case travelModeChanged(TravelMode)

    case travelScopeChanged(TravelScope)

    case tripTypeChanged(TripType)

    /// A real change of date drops every leg already picked — see
    /// `FlightBookingBloc.setSearchDate`.
    case departDateChanged(DateTime)

    /// `nil` clears the return date.
    case returnDateChanged(DateTime?)

    case fromLocationChanged(LocationModel)

    case toLocationChanged(LocationModel)

    case locationsSwapped

    /// Adults. Clamped so the booking never passes
    /// `FlightBookingState.maxTravellers`; lap infants follow the adult count down.
    case adultCountChanged(Int)

    case childCountChanged(Int)

    /// One lap per adult — infants are capped at the adult count.
    case infantCountChanged(Int)

    case cabinClassChanged(TravelClass)

    case nationalityChanged(Nationality)

    // ---- Results -----------------------------------------------------------

    /// The Home form's Search button: clears any earlier picks, runs the search
    /// and moves the tracker to the detail stage.
    case flightSearchRequested

    /// Rebuilds the visible results for the current leg without the skeleton —
    /// used when switching legs, where the data is already loaded.
    case resultsRefreshed

    /// Shows the skeleton, optionally switches the active date, then reveals the
    /// refreshed results. A newer reload cancels one still in flight.
    case resultsReloaded(date: DateTime? = nil)

    /// Changes the date shown by the date strip and refreshes the list in place,
    /// without the skeleton and without moving the progress stage.
    case activeDateSelected(DateTime)

    /// Refreshes the per-day "from" prices under the date chips. Raised by the
    /// bloc itself after each load (Dart's private `_DailyMinPricesRequested`),
    /// so only the bloc sends it.
    case dailyMinPricesRequested

    case sortOrderChanged(ascending: Bool)

    /// The filter sheet's selection. Every field replaces the current one —
    /// `nil` means "any" — and the search is re-run so the filters apply to the
    /// full result set.
    case filtersApplied(
        maxStops: Int? = nil,
        classFilter: TravelClass? = nil,
        maxPrice: Double? = nil,
        airlines: Set<String>? = nil,
        departureTimes: Set<String>? = nil
    )

    // ---- Selection & checkout ----------------------------------------------

    case outboundSelected(TripOptionModel)

    case inboundSelected(TripOptionModel)

    /// Opens the enquiry form straight from a commercial timetable card, keeping
    /// the catalogue's route, flight number, fare and next operating date.
    case commercialFlightEnquiryStarted(TripOptionModel)

    /// Back to choosing the departure leg: clears the picked legs and reloads the
    /// departure list.
    case outboundSelectionRestarted

    case continuedToPayment

    /// Back from the reservation confirmation to amend the traveller form. The
    /// next submission must create a fresh hold.
    case returnedFromConfirmation

    /// Keeps the MAI traveller/contact form data until payment is confirmed and
    /// `holdFlight` can be submitted with the selected method.
    case holdRequestSaved(FlightHoldRequest)

    /// The airline has reserved the seats; advances to the confirmation stage.
    case heldReservationConfirmed(request: FlightHoldRequest, response: FlightHoldResponse)

    /// Rebuilds the checkout for a held booking so payment can pick it up where it
    /// was left.
    ///
    /// `stage` says which checkout step to land on. Signed-in customers resume
    /// straight into payment from their history; a guest coming back with only a
    /// reference lands on the reservation confirmation first, to check the booking
    /// they just looked up before paying for it.
    case heldBookingResumed(
        from: LocationModel,
        to: LocationModel,
        departDate: DateTime,
        adults: Int,
        children: Int,
        infants: Int,
        cabinClass: TravelClass,
        outbound: TripOptionModel,
        inbound: TripOptionModel? = nil,
        holdRequest: FlightHoldRequest,
        holdResponse: FlightHoldResponse,
        stage: BookingStage = .payment
    )

    case returnedFromPayment

    case bookingCompleted

    /// Clears the flow back to a fresh search, keeping the chosen route/date.
    case bookingReset
}
