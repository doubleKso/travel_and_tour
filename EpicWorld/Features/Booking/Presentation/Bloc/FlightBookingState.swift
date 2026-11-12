// Port of lib/features/booking/presentation/bloc/flight_booking_state.dart

import Foundation

/// Everything the search → detail → payment → completed flow needs, as one
/// immutable value.
///
/// Widgets read fields and computed getters off this; only `FlightBookingBloc`
/// produces a new instance, in response to a `FlightBookingEvent`. Keeping the
/// derived rules (passport requirements, totals, which leg is being picked)
/// here means a page never re-implements them.
struct FlightBookingState {
    /// The only airline that can be booked & paid for in-app. Every other
    /// airline is reservation-only (the customer pays at the office).
    static let bookableAirline = "MAI Airway"

    // ---- Search criteria ---------------------------------------------------
    let mode: TravelMode
    let scope: TravelScope
    let tripType: TripType
    let departDate: DateTime
    let returnDate: DateTime?
    let fromLocation: LocationModel
    let toLocation: LocationModel

    /// Home opens with Yangon International Airport (RGN) selected as the
    /// departure point. The destination remains a fallback until the traveller
    /// chooses it, so a route cannot be searched accidentally.
    let isFromLocationSelected: Bool
    let isToLocationSelected: Bool

    /// Adults. Children and infants are tracked separately so the traveller
    /// sheet can break them out.
    let travellerCount: Int
    let childCount: Int
    let infantCount: Int
    let cabinClass: TravelClass
    let nationality: Nationality

    // ---- Flow state --------------------------------------------------------
    let stage: BookingStage
    let isLoading: Bool
    let results: [TripOptionModel]

    /// Airline names from the latest unfiltered search response. The filter
    /// sheet reads this instead of the visible (possibly filtered) results so
    /// unchecked airline choices do not disappear after applying a filter.
    let availableAirlines: Set<String>

    /// Airline branding from the same unfiltered response, keyed by display
    /// name. Keeping it beside `availableAirlines` lets the filter sheet retain
    /// each carrier's logo/code even after that carrier is filtered out of the
    /// visible result list.
    let availableAirlineLogoUrls: [String: String]
    let availableAirlineCodes: [String: String]

    /// Highest fare in the latest unfiltered search response, or 0 when there
    /// were none. The filter sheet sizes its price slider from this rather than
    /// from the visible results, so applying a price filter cannot shrink the
    /// slider's own ceiling — the same reason `availableAirlines` is tracked.
    let priceCeiling: Double
    let selectedOutbound: TripOptionModel?
    let selectedInbound: TripOptionModel?

    /// User-entered MAI booking data, retained while the customer chooses a
    /// payment method on the next screens.
    let holdRequest: FlightHoldRequest?

    /// The successful seat reservation returned by `holdFlight`. Keeping this
    /// separately prevents the payment page from making a second hold request.
    let holdResponse: FlightHoldResponse?

    // ---- Sorting / filtering (nil = "any") ---------------------------------
    let sortByPriceAsc: Bool
    let maxStops: Int?
    let classFilter: TravelClass?
    let maxPrice: Double?
    let airlineFilter: Set<String>?
    let departureTimeFilter: Set<String>?

    /// Cheapest fare per calendar day for the current route, keyed by
    /// `DateTime(y, m, d)`. Filled by the bloc so the date strip can read a
    /// price synchronously while building.
    let dailyMinPrices: [DateTime: Double]

    init(
        departDate: DateTime,
        mode: TravelMode = .flight,
        scope: TravelScope = .domestic,
        tripType: TripType = .oneWay,
        returnDate: DateTime? = nil,
        fromLocation: LocationModel = LocationModel.defaultOrigin,
        toLocation: LocationModel = LocationModel.defaultDestination,
        isFromLocationSelected: Bool = false,
        isToLocationSelected: Bool = false,
        travellerCount: Int = 1,
        childCount: Int = 0,
        infantCount: Int = 0,
        cabinClass: TravelClass = .economy,
        nationality: Nationality = .myanmar,
        stage: BookingStage = .search,
        isLoading: Bool = false,
        results: [TripOptionModel] = [],
        availableAirlines: Set<String> = [],
        availableAirlineLogoUrls: [String: String] = [:],
        availableAirlineCodes: [String: String] = [:],
        priceCeiling: Double = 0,
        selectedOutbound: TripOptionModel? = nil,
        selectedInbound: TripOptionModel? = nil,
        holdRequest: FlightHoldRequest? = nil,
        holdResponse: FlightHoldResponse? = nil,
        sortByPriceAsc: Bool = true,
        maxStops: Int? = nil,
        classFilter: TravelClass? = nil,
        maxPrice: Double? = nil,
        airlineFilter: Set<String>? = nil,
        departureTimeFilter: Set<String>? = nil,
        dailyMinPrices: [DateTime: Double] = [:]
    ) {
        self.departDate = departDate
        self.mode = mode
        self.scope = scope
        self.tripType = tripType
        self.returnDate = returnDate
        self.fromLocation = fromLocation
        self.toLocation = toLocation
        self.isFromLocationSelected = isFromLocationSelected
        self.isToLocationSelected = isToLocationSelected
        self.travellerCount = travellerCount
        self.childCount = childCount
        self.infantCount = infantCount
        self.cabinClass = cabinClass
        self.nationality = nationality
        self.stage = stage
        self.isLoading = isLoading
        self.results = results
        self.availableAirlines = availableAirlines
        self.availableAirlineLogoUrls = availableAirlineLogoUrls
        self.availableAirlineCodes = availableAirlineCodes
        self.priceCeiling = priceCeiling
        self.selectedOutbound = selectedOutbound
        self.selectedInbound = selectedInbound
        self.holdRequest = holdRequest
        self.holdResponse = holdResponse
        self.sortByPriceAsc = sortByPriceAsc
        self.maxStops = maxStops
        self.classFilter = classFilter
        self.maxPrice = maxPrice
        self.airlineFilter = airlineFilter
        self.departureTimeFilter = departureTimeFilter
        self.dailyMinPrices = dailyMinPrices
    }

    /// Defaults the search form opens with RGN and today's date for both legs.
    /// The same departure date remains in place when the traveller switches
    /// between one-way and round-trip search.
    static func initial() -> FlightBookingState {
        let now = DateTime.now()
        let today = DateTime(now.year, now.month, now.day)
        return FlightBookingState(
            departDate: today,
            returnDate: today,
            isFromLocationSelected: true
        )
    }

    /// Both endpoints have been explicitly selected on the search form.
    var hasCompleteRoute: Bool { isFromLocationSelected && isToLocationSelected }

    // ---- Derived rules -----------------------------------------------------

    /// Whether one `option` is operated by MAI, the only airline that supports
    /// instant in-app booking. Live results identify MAI with IATA code `8M`;
    /// the display-name checks keep existing mock and legacy results working.
    static func isBookableOption(_ option: TripOptionModel) -> Bool {
        if let bookable = option.bookable { return bookable }
        if option.carrierCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "8M" { return true }
        let airline = option.operatorName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return airline == bookableAirline.lowercased()
            || airline == "mai"
            || airline == "myanmar airways"
            || airline == "myanmar airways international"
    }

    /// MAI checkout is available only when every selected flight can be booked
    /// in-app. A mixed round trip (for example MAI outbound, Air KBZ return)
    /// therefore opens the non-MAI reservation form rather than losing the
    /// selected return flight in the MAI payment flow.
    var isBookableSelected: Bool {
        let selectedLegs = [selectedOutbound, selectedInbound].compactMap { $0 }
        return !selectedLegs.isEmpty && selectedLegs.allSatisfy(Self.isBookableOption)
    }

    /// Total passengers across adults + children + infants.
    var totalTravellers: Int { travellerCount + childCount + infantCount }

    /// Most travellers one booking can hold, adults, children and infants
    /// together — the same limit the web portal applies.
    static let maxTravellers = 9

    private var seatsLeft: Int { Self.maxTravellers - totalTravellers }

    /// Highest adult count the traveller picker may reach right now.
    var maxAdults: Int { max(1, travellerCount + seatsLeft) }

    /// Highest child count the traveller picker may reach right now.
    var maxChildren: Int { max(0, childCount + seatsLeft) }

    /// Highest infant count right now. Infants sit on an adult's lap, so the
    /// adult count caps them as well as the seats left.
    var maxInfants: Int { max(0, min(travellerCount, infantCount + seatsLeft)) }

    /// True when a location is inside Myanmar.
    private static func inMyanmar(_ location: LocationModel) -> Bool {
        location.country.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "myanmar"
    }

    /// Domestic vs international judged by the route actually chosen, not by the
    /// search form's toggle.
    ///
    /// Yangon → Mandalay is a domestic journey however the toggle happens to be
    /// set, and the toggle is free to disagree with the airports the customer
    /// picked. Document rules key off this so a domestic route never demands a
    /// passport from a Myanmar citizen. Falls back to `scope` when either
    /// location has no country — some feeds leave it blank, and a guess there
    /// would be worse than honouring what the customer selected.
    var effectiveScope: TravelScope {
        if fromLocation.country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || toLocation.country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return scope
        }
        return Self.inMyanmar(fromLocation) && Self.inMyanmar(toLocation) ? .domestic : .international
    }

    /// True when the journey crosses a border — see `effectiveScope`.
    var isInternationalTrip: Bool { effectiveScope == .international }

    /// Whether a passport / national-ID number must be provided on the traveller
    /// form. Mandatory for international trips and for any non-Myanmar
    /// (foreigner) traveller; optional for domestic Myanmar citizens.
    var passportRequired: Bool { isInternationalTrip || nationality == .foreigner }

    /// True when the home Nationality dropdown is set to Other.
    var isForeigner: Bool { nationality == .foreigner }

    /// Per-traveller passport rule:
    ///   domestic  + Myanmar   → not required (the NRC identifies them)
    ///   domestic  + foreigner → required (they hold no Myanmar NRC)
    ///   international         → required for every traveller, infants included
    func passportRequiredFor(travellerIsMyanmar: Bool) -> Bool {
        isInternationalTrip || !travellerIsMyanmar
    }

    /// Per-traveller NRC rule — Myanmar citizens only:
    ///   domestic      → adults only
    ///   international → every traveller, children and infants included
    ///                   (collected alongside the passport)
    func nrcRequiredFor(travellerIsMyanmar: Bool, isAdult: Bool) -> Bool {
        travellerIsMyanmar && (isInternationalTrip || isAdult)
    }

    /// True while the user is choosing the return leg (round-trip, outbound
    /// already chosen, inbound not yet).
    var isPickingReturn: Bool {
        tripType == .roundTrip && selectedOutbound != nil && selectedInbound == nil
    }

    /// The date the visible results belong to — the return date while picking
    /// the return leg, otherwise the departure date.
    var activeDate: DateTime { isPickingReturn ? (returnDate ?? departDate) : departDate }

    /// Origin for the leg being searched (swapped on the return leg).
    var searchFrom: LocationModel { isPickingReturn ? toLocation : fromLocation }

    /// Destination for the leg being searched.
    var searchTo: LocationModel { isPickingReturn ? fromLocation : toLocation }

    /// Cabin the next search should ask the service for.
    ///
    /// The results list can only narrow what the service returned, so the class
    /// picked in the filter sheet has to reach the request itself — filtering
    /// for Business over an Economy-only response just empties the list. Falls
    /// back to the cabin chosen on the search form when the filter is "Any".
    var searchCabin: TravelClass { classFilter ?? cabinClass }

    /// Return date the next search should send.
    ///
    /// Only the outbound search of a round trip carries one. The return leg is
    /// looked up on its own, with the route swapped and `activeDate` already on
    /// the return date. `returnDate` alone can't decide this, because a one-way
    /// search keeps the default it opened with.
    var searchReturnDate: DateTime? {
        tripType == .roundTrip && !isPickingReturn ? returnDate : nil
    }

    /// Whether the user still needs to pick a return leg before paying.
    var needsReturnSelection: Bool { tripType == .roundTrip && selectedInbound == nil }

    var totalPrice: Double { (selectedOutbound?.price ?? 0) + (selectedInbound?.price ?? 0) }

    /// Lowest available fare on `date` for the current route/mode, or nil when
    /// prices for that day haven't been loaded.
    func minPriceOn(_ date: DateTime) -> Double? {
        dailyMinPrices[DateTime(date.year, date.month, date.day)]
    }

    func copyWith(
        mode: TravelMode? = nil,
        scope: TravelScope? = nil,
        tripType: TripType? = nil,
        departDate: DateTime? = nil,
        returnDate: DateTime? = nil,
        fromLocation: LocationModel? = nil,
        toLocation: LocationModel? = nil,
        isFromLocationSelected: Bool? = nil,
        isToLocationSelected: Bool? = nil,
        travellerCount: Int? = nil,
        childCount: Int? = nil,
        infantCount: Int? = nil,
        cabinClass: TravelClass? = nil,
        nationality: Nationality? = nil,
        stage: BookingStage? = nil,
        isLoading: Bool? = nil,
        results: [TripOptionModel]? = nil,
        availableAirlines: Set<String>? = nil,
        availableAirlineLogoUrls: [String: String]? = nil,
        availableAirlineCodes: [String: String]? = nil,
        priceCeiling: Double? = nil,
        selectedOutbound: TripOptionModel? = nil,
        selectedInbound: TripOptionModel? = nil,
        holdRequest: FlightHoldRequest? = nil,
        holdResponse: FlightHoldResponse? = nil,
        sortByPriceAsc: Bool? = nil,
        maxStops: Int? = nil,
        classFilter: TravelClass? = nil,
        maxPrice: Double? = nil,
        airlineFilter: Set<String>? = nil,
        departureTimeFilter: Set<String>? = nil,
        dailyMinPrices: [DateTime: Double]? = nil,
        clearReturnDate: Bool = false,
        clearOutbound: Bool = false,
        clearInbound: Bool = false,
        clearHoldRequest: Bool = false,
        clearHoldResponse: Bool = false,
        clearFilters: Bool = false
    ) -> FlightBookingState {
        FlightBookingState(
            departDate: departDate ?? self.departDate,
            mode: mode ?? self.mode,
            scope: scope ?? self.scope,
            tripType: tripType ?? self.tripType,
            returnDate: clearReturnDate ? nil : (returnDate ?? self.returnDate),
            fromLocation: fromLocation ?? self.fromLocation,
            toLocation: toLocation ?? self.toLocation,
            isFromLocationSelected: isFromLocationSelected ?? self.isFromLocationSelected,
            isToLocationSelected: isToLocationSelected ?? self.isToLocationSelected,
            travellerCount: travellerCount ?? self.travellerCount,
            childCount: childCount ?? self.childCount,
            infantCount: infantCount ?? self.infantCount,
            cabinClass: cabinClass ?? self.cabinClass,
            nationality: nationality ?? self.nationality,
            stage: stage ?? self.stage,
            isLoading: isLoading ?? self.isLoading,
            results: results ?? self.results,
            availableAirlines: availableAirlines ?? self.availableAirlines,
            availableAirlineLogoUrls: availableAirlineLogoUrls ?? self.availableAirlineLogoUrls,
            availableAirlineCodes: availableAirlineCodes ?? self.availableAirlineCodes,
            priceCeiling: priceCeiling ?? self.priceCeiling,
            selectedOutbound: clearOutbound ? nil : (selectedOutbound ?? self.selectedOutbound),
            selectedInbound: clearInbound ? nil : (selectedInbound ?? self.selectedInbound),
            holdRequest: clearHoldRequest ? nil : (holdRequest ?? self.holdRequest),
            holdResponse: clearHoldResponse ? nil : (holdResponse ?? self.holdResponse),
            sortByPriceAsc: sortByPriceAsc ?? self.sortByPriceAsc,
            // With `clearFilters: true` the passed values win outright — that is how
            // "apply these filters, and drop the ones the user cleared" is expressed.
            maxStops: clearFilters ? maxStops : (maxStops ?? self.maxStops),
            classFilter: clearFilters ? classFilter : (classFilter ?? self.classFilter),
            maxPrice: clearFilters ? maxPrice : (maxPrice ?? self.maxPrice),
            airlineFilter: clearFilters ? airlineFilter : (airlineFilter ?? self.airlineFilter),
            departureTimeFilter: clearFilters
                ? departureTimeFilter
                : (departureTimeFilter ?? self.departureTimeFilter),
            dailyMinPrices: dailyMinPrices ?? self.dailyMinPrices
        )
    }
}
