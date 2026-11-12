// Port of lib/features/booking/presentation/widgets/trip_option_card.dart

import SwiftUI

private let cardBorder = Color(0xFFECEEF3)
private let dotColor = Color(0xFFC9CDD6)

/// Itinerary-style flight-result card (see the reference design).
///
/// Header: airline logo + flight number / name on the left; cabin class and
/// baggage on the right. Below a divider, the route shows each end's date, big
/// time, and code (city), joined by a dashed line + plane with a duration pill.
/// A slim footer carries "Flight Info" and the price.
///
/// Tapping the card's flight-details affordance opens the boarding-pass style
/// bottom sheet, where the traveller can review and choose a fare option.
struct TripOptionCard: View {
    let option: TripOptionModel
    let selected: Bool
    let onTap: (TripOptionModel) -> Void
    let enquiryOnly: Bool

    @State private var fareIndex: Int
    @State private var mounted = false

    init(
        option: TripOptionModel,
        onTap: @escaping (TripOptionModel) -> Void,
        selected: Bool = false,
        enquiryOnly: Bool = false
    ) {
        self.option = option
        self.onTap = onTap
        self.selected = selected
        self.enquiryOnly = enquiryOnly
        _fareIndex = State(initialValue: Self.initialFareIndex(option))
    }

    private static func initialFareIndex(_ option: TripOptionModel) -> Int {
        option.fareOptions.firstIndex { $0.selected } ?? 0
    }

    private var isFlight: Bool { option.mode == .flight }

    private var chosenOption: TripOptionModel {
        option.fareOptions.indices.contains(fareIndex)
            ? option.withFare(option.fareOptions[fareIndex])
            : option
    }

    @MainActor
    private func showFlightDetails() async {
        let sheetOption = chosenOption
        let isFlight = self.isFlight
        let enquiryOnly = self.enquiryOnly
        let chosen: TripOptionModel? = await showModalBottomSheet(
            isScrollControlled: true,
            backgroundColor: Colors.transparent
        ) { dismiss in
            FlightDetailsSheet(
                option: sheetOption,
                isFlight: isFlight,
                enquiryOnly: enquiryOnly,
                onSelect: { dismiss($0) }
            )
            // FractionallySizedBox(heightFactor: 0.88).
            .containerRelativeFrame(.vertical) { length, _ in length * 0.88 }
        }
        guard mounted, let chosen else { return }

        let updatedFareIndex = option.fareOptions.firstIndex { fare in
            ((fare.basis?.isEmpty == false) && fare.basis == chosen.fareBasis)
                || fare.brand == chosen.fareBrand
        }
        if let updatedFareIndex {
            fareIndex = updatedFareIndex
        }
        onTap(chosen)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                AirlineLogo(
                    name: option.operatorName,
                    logoUrl: option.operatorLogoUrl,
                    carrierCode: option.carrierCode,
                    size: 21
                )
                HGap(7)
                Text(option.operatorName)
                    .textStyle(AppTypography.body(13, weight: .w700))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ResultPill(
                    label: enquiryOnly ? "Enquiry only" : option.travelClass.label,
                    color: enquiryOnly ? Color(0xFFD86500) : AppColors.primary,
                    icon: enquiryOnly ? Icons.mail_outline_rounded : Icons.luggage_outlined
                )
            }
            VGap(13)
            // ── Route header: departure time over "CODE · City" on
            // the left, the duration / plane line / stops in the
            // middle, and the arrival end on the right.
            HStack(alignment: .center, spacing: 0) {
                SheetEndpoint(
                    time: Formatters.time12(option.departure),
                    code: option.originCode,
                    name: option.originName
                )
                TicketRouteMiddle(
                    isFlight: isFlight,
                    duration: Formatters.duration(option.duration),
                    stops: option.isDirect
                        ? "Non-stop"
                        : "\(option.stops) stop\(option.stops > 1 ? "s" : "")"
                )
                .frame(maxWidth: .infinity)
                SheetEndpoint(
                    time: Formatters.time12(option.arrival),
                    code: option.destinationCode,
                    name: option.destinationName,
                    alignEnd: true
                )
            }
            VGap(12)
            DottedDivider()
            VGap(12)
            // ── Bottom: logo + airline name (left); cabin class over
            // its price (right).
            HStack(alignment: .center, spacing: 0) {
                AirlineLogo(
                    name: option.operatorName,
                    logoUrl: option.operatorLogoUrl,
                    carrierCode: option.carrierCode,
                    size: 36
                )
                HGap(11)
                Text("Flight details")
                    .textStyle(AppTypography.body(13, weight: .w600, color: AppColors.textSecondary))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HGap(10)
                // Price (replaces the cabin-class badge here).
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(Formatters.grouped(Int(chosenOption.price.rounded())))
                        .textStyle(AppTypography.heading(18, weight: .w800, color: AppColors.primaryDark))
                    HGap(3)
                    Text(chosenOption.currency)
                        .textStyle(AppTypography.body(11, weight: .w600, color: AppColors.textPrimary))
                }
            }
            VGap(8)
            Button {
                Task { await showFlightDetails() }
            } label: {
                HStack(spacing: 0) {
                    Text("Flight details")
                        .textStyle(AppTypography.body(13, weight: .w700))
                    HGap(4)
                    Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.textPrimary)
                    Spacer(minLength: 0)
                    Text(enquiryOnly ? "Indicative fare" : "per passenger")
                        .textStyle(AppTypography.body(11, color: AppColors.textPrimary))
                }
                .padding(.vertical, 5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.ink(radius: 8))
        }
        .padding(16, 14, 16, 14)
        .boxDecoration(
            color: AppColors.surface,
            radius: 20,
            borderColor: selected ? AppColors.primary : cardBorder,
            borderWidth: selected ? 1.6 : 1,
            shadows: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: selected ? 0.10 : 0.05),
                    blurRadius: selected ? 16 : 10,
                    offset: Offset(0, 4)
                ),
            ]
        )
        .contentShape(Rectangle())
        .onTapGesture { Task { await showFlightDetails() } }
        // Selected check badge, nudged just outside the top-right corner.
        .overlay(alignment: .topTrailing) {
            if selected {
                Icon(Icons.check, size: 14, color: Colors.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(AppColors.primary))
                    .padding(3)
                    .background(Circle().fill(AppColors.surface))
                    .offset(x: 7, y: -7)
            }
        }
        .padding(.bottom, 12)
        .onAppear { mounted = true }
        .onDisappear { mounted = false }
        // didUpdateWidget: a different option resets the chosen fare.
        .onChange(of: option.id) {
            fareIndex = Self.initialFareIndex(option)
        }
    }
}

/// Dart `_ResultPill`.
private struct ResultPill: View {
    let label: String
    let color: Color
    let icon: IconData

    var body: some View {
        HStack(spacing: 0) {
            Icon(icon, size: 13, color: color)
            HGap(4)
            Text(label)
                .textStyle(AppTypography.body(10.5, weight: .w700, color: color))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .boxDecoration(color: color.withValues(alpha: 0.10), radius: 14)
    }
}

/// Dart `_FareChoice`.
private struct FareChoice: View {
    let fare: FareOptionModel
    let selected: Bool
    let lowestPrice: Double
    let onTap: () -> Void

    private var isLowest: Bool { fare.price == lowestPrice }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                    Icon(
                        selected ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 20,
                        color: selected ? AppColors.primary : AppColors.textTertiary
                    )
                    HGap(8)
                    Text(fare.brand)
                        .textStyle(AppTypography.body(13, weight: .w800))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if isLowest {
                        HGap(6)
                        LowestBadge()
                    }
                }
                VGap(5)
                Text("\(fare.travelClass.label) · \(fare.baggageKg ?? 20)kg")
                    .textStyle(AppTypography.body(11, color: AppColors.textSecondary))
                    .lineLimit(1)
                    .truncationMode(.tail)
                MaterialDivider(height: 21, color: AppColors.divider)
                HStack(alignment: .bottom, spacing: 0) {
                    // FittedBox(fit: BoxFit.scaleDown, alignment: centerLeft).
                    Text(Formatters.grouped(Int(fare.price.rounded())))
                        .textStyle(AppTypography.heading(17, weight: .w800, color: AppColors.primaryDark))
                        .lineLimit(1)
                        .minimumScaleFactor(0.1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HGap(4)
                    Text(fare.currency)
                        .textStyle(AppTypography.body(10, weight: .w700, color: AppColors.textPrimary))
                }
                if !isLowest {
                    Text("+\(Formatters.grouped(Int((fare.price - lowestPrice).rounded()))) vs lowest")
                        .textStyle(AppTypography.body(10, color: AppColors.textPrimary))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.top, 4)
                }
            }
            .padding(13, 12, 13, 10)
            .boxDecoration(
                color: selected ? AppColors.primarySurface : AppColors.surface,
                radius: 13,
                borderColor: selected ? AppColors.primary : AppColors.border,
                borderWidth: selected ? 1.6 : 1
            )
            .contentShape(RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.ink(radius: 13))
    }
}

/// Dart `_FareOptionsRow`.
private struct FareOptionsRow: View {
    let fares: [FareOptionModel]
    let selectedIndex: Int
    let onSelected: (Int) -> Void

    var body: some View {
        let lowestFare = fares.map(\.price).reduce(fares[0].price) { lowest, price in price < lowest ? price : lowest }
        VStack(alignment: .leading, spacing: 0) {
            Text("Fare options")
                .textStyle(AppTypography.body(14, weight: .w800))
            VGap(10)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(fares.enumerated()), id: \.offset) { index, fare in
                        FareChoice(
                            fare: fare,
                            selected: index == selectedIndex,
                            lowestPrice: lowestFare,
                            onTap: { onSelected(index) }
                        )
                        .frame(width: 278)
                    }
                }
            }
            .scrollClipDisabled()
            .frame(height: 136)
        }
    }
}

/// Dart `_LowestBadge`.
private struct LowestBadge: View {
    var body: some View {
        Text("LOWEST")
            .textStyle(AppTypography.body(8.5, weight: .w800, color: AppColors.primaryDark))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .boxDecoration(color: AppColors.primarySurface, radius: 8)
    }
}

/// Amenities offered per cabin class (richer classes inherit the lower ones).
func amenitiesFor(_ tc: TravelClass) -> [String] {
    switch tc {
    case .economy: return ["Carry-on"]
    // TravelClass.premiumEconomy => const ['Carry-on', 'In-flight snack'],
    case .business: return ["Carry-on", "In-flight snack", "Free meal"]
    // TravelClass.first => const [
    //   'Carry-on',
    //   'In-flight snack',
    //   'Free meal',
    //   'Lounge',
    // ],
    }
}

// ---------------------------------------------------------------------------
// Flight details bottom sheet — a boarding-pass-style summary.
// ---------------------------------------------------------------------------

/// Rich, attractive flight summary shown when "Flight Details" is tapped.
///
/// Sections (top → bottom):
///   1. Gradient header — airline logo + name + cabin class
///   2. Route          — From → To with the duration / stops line
///   3. Fare options   — selectable fare cards (paid options only)
///   4. Amenities      — class-based perk chips
///   5. Details        — operated-by, baggage, class rows
///   6. Actions        — Close / Select
struct FlightDetailsSheet: View {
    let option: TripOptionModel
    let isFlight: Bool
    let enquiryOnly: Bool
    let onSelect: (TripOptionModel) -> Void

    @State private var fareIndex: Int

    @Environment(AppContainer.self) private var container
    @Environment(\.dismissModal) private var dismissModal

    init(
        option: TripOptionModel,
        isFlight: Bool,
        enquiryOnly: Bool,
        onSelect: @escaping (TripOptionModel) -> Void
    ) {
        self.option = option
        self.isFlight = isFlight
        self.enquiryOnly = enquiryOnly
        self.onSelect = onSelect
        _fareIndex = State(initialValue: Self.initialFareIndex(option))
    }

    private static func initialFareIndex(_ option: TripOptionModel) -> Int {
        option.fareOptions.firstIndex { fare in
            ((fare.basis?.isEmpty == false) && fare.basis == option.fareBasis)
                || fare.brand == option.fareBrand
                || fare.selected
        } ?? 0
    }

    /// Dart's state getter `option`: the itinerary with the chosen fare applied.
    private var chosenOption: TripOptionModel {
        option.fareOptions.indices.contains(fareIndex)
            ? option.withFare(option.fareOptions[fareIndex])
            : option
    }

    var body: some View {
        VStack(spacing: 0) {
            VGap(10)
            // Drag handle.
            RoundedRectangle(cornerRadius: 2)
                .fill(AppColors.border)
                .frame(width: 42, height: 4)
            // Flexible(SingleChildScrollView): sized to its content, scrolling
            // only when the content is taller than the sheet.
            ViewThatFits(in: .vertical) {
                details
                ScrollView { details }
            }
            // 6. Actions.
            Button {
                onSelect(chosenOption)
            } label: {
                Text(enquiryOnly ? "Enquire" : LocaleKeys.booking_select_flight.tr())
                    .textStyle(AppTypography.body(15, weight: .w700, color: Colors.white))
            }
            .buttonStyle(
                ElevatedButtonStyle(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    cornerRadius: 12,
                    padding: EdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24),
                    elevation: 0
                )
            )
            .padding(16, 8, 16, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            UnevenRoundedRectangle(cornerRadii: BorderRadius.vertical(top: 28), style: .circular)
                .fill(AppColors.surface)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    @MainActor
    private var details: some View {
        let option = chosenOption
        let amenities = amenitiesFor(option.travelClass)
        let stopsLabel = option.isDirect ? "Non-stop" : "\(option.stops) stop\(option.stops > 1 ? "s" : "")"
        return VStack(alignment: .leading, spacing: 0) {
            // 1. Airline header (plain — no gradient).
            HStack(spacing: 0) {
                AirlineLogo(
                    name: option.operatorName,
                    logoUrl: option.operatorLogoUrl,
                    carrierCode: option.carrierCode,
                    size: 72
                )
                HGap(14)
                VStack(alignment: .leading, spacing: 0) {
                    Text(option.operatorName)
                        .textStyle(AppTypography.heading(17))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    VGap(3)
                    Text("\(isFlight ? "Flight" : "Bus") · \(option.travelClass.label)")
                        .textStyle(AppTypography.body(12.5, color: AppColors.textSecondary))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Icon(Icons.close, size: 22, color: AppColors.textSecondary)
                    .contentShape(Rectangle())
                    .onTapGesture { dismissModal() }
            }
            VGap(14)
            MaterialDivider(height: 1, color: AppColors.divider)
            VGap(14)

            // 2. Route summary — big times with code · city beneath, and
            // the duration / stops line in the middle.
            HStack(alignment: .center, spacing: 0) {
                SheetEndpoint(
                    time: Formatters.time12(option.departure),
                    code: option.originCode
                )
                TicketRouteMiddle(
                    isFlight: isFlight,
                    duration: Formatters.duration(option.duration),
                    stops: stopsLabel
                )
                .frame(maxWidth: .infinity)
                SheetEndpoint(
                    time: Formatters.time12(option.arrival),
                    code: option.destinationCode,
                    alignEnd: true
                )
            }
            VGap(18)
            MaterialDivider(height: 1, color: AppColors.divider)
            VGap(16)

            // 3. Fare options — kept directly under the route so the
            // fare being chosen sits with the flight it prices, rather
            // than below the detail rows where it was easy to miss.
            if !enquiryOnly && !self.option.fareOptions.isEmpty {
                FareOptionsRow(
                    fares: self.option.fareOptions,
                    selectedIndex: fareIndex,
                    onSelected: { index in fareIndex = index }
                )
                VGap(16)
                MaterialDivider(height: 1, color: AppColors.divider)
                VGap(16)
            }

            // 4. Amenities.
            Text(LocaleKeys.common_amenities.tr())
                .textStyle(AppTypography.body(12, weight: .w700, color: AppColors.textSecondary))
            VGap(10)
            WrapLayout(spacing: 8, runSpacing: 8) {
                ForEach(amenities, id: \.self) { amenity in
                    AmenityChip(label: amenity)
                }
            }
            VGap(16)
            MaterialDivider(height: 1, color: AppColors.divider)
            VGap(12)

            // 5. Detail rows.
            if let flightNumber = option.flightNumber?.trimmingCharacters(in: .whitespacesAndNewlines),
               !flightNumber.isEmpty {
                InfoRow(
                    icon: Icons.confirmation_number_outlined,
                    label: LocaleKeys.booking_flight_number.tr(),
                    value: flightNumber,
                    valueColor: AppColors.primaryDark
                )
            }
            InfoRow(
                icon: Icons.business_rounded,
                label: LocaleKeys.booking_operated_by.tr(),
                value: option.operatorName,
                valueColor: AppColors.primaryDark
            )
            InfoRow(
                icon: Icons.event_rounded,
                label: LocaleKeys.booking_date.tr(),
                value: Formatters.fullDate(option.departure)
            )
            InfoRow(
                icon: Icons.flight_takeoff_rounded,
                label: LocaleKeys.common_from.tr(),
                value: "\(airportName(option.originCode)) (\(option.originCode))"
            )
            InfoRow(
                icon: Icons.flight_land_rounded,
                label: LocaleKeys.common_to.tr(),
                value: "\(airportName(option.destinationCode)) (\(option.destinationCode))"
            )
            InfoRow(
                icon: Icons.alt_route_rounded,
                label: LocaleKeys.booking_stops.tr(),
                value: stopsLabel
            )
            InfoRow(
                icon: Icons.airline_seat_recline_normal_rounded,
                label: LocaleKeys.common_class.tr(),
                trailing: AnyView(TripClassBadge(travelClass: option.travelClass))
            )
            InfoRow(
                icon: Icons.luggage_rounded,
                label: LocaleKeys.booking_baggage.tr(),
                value: "\(option.baggageKg ?? 20) kg checked + carry-on"
            )
            VGap(14)
            if enquiryOnly {
                Text(
                    "This airline does not sell online. Send an enquiry and our office will confirm the seat and fare with them."
                )
                .textStyle(AppTypography.body(12, color: Color(0xFFAD4A09)))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .boxDecoration(color: Color(0xFFFFF7EC), radius: 10)
            }
        }
        .padding(16, 16, 16, 8)
    }

    /// Full airport name for an IATA code, looked up from the location list.
    @MainActor
    private func airportName(_ code: String) -> String {
        let locations = container.locationList.state.valueOrNull ?? []
        for location in locations where location.code == code {
            return location.facilityName
        }
        return code
    }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

/// Dart `_AmenityChip`.
private struct AmenityChip: View {
    let label: String

    var body: some View {
        HStack(spacing: 0) {
            Icon(Icons.check_circle, size: 14, color: AppColors.primary)
            HGap(6)
            Text(label)
                .textStyle(AppTypography.body(12, weight: .w500, color: AppColors.primaryDark))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .boxDecoration(color: AppColors.primarySurface, radius: 20)
    }
}

/// Dart `_InfoRow`.
private struct InfoRow: View {
    let icon: IconData
    let label: String
    var value: String = ""
    var valueColor: Color? = nil

    /// Optional widget shown right-aligned instead of the `value` text (e.g. a
    /// class badge).
    var trailing: AnyView? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Icon(icon, size: 18, color: AppColors.primary)
            HGap(12)
            Text(label)
                .textStyle(AppTypography.body(13, color: AppColors.textSecondary))
            HGap(12)
            Group {
                if let trailing {
                    trailing
                } else {
                    Text(value)
                        .textStyle(AppTypography.body(13, weight: .w600, color: valueColor ?? AppColors.textPrimary))
                        .multilineTextAlignment(.trailing)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 7)
    }
}

// ---------------------------------------------------------------------------
// Itinerary result-card sub-widgets
// ---------------------------------------------------------------------------

/// Distinct accent colour per cabin class. Economy is a teal (not the brand
/// green) so it doesn't blend into the primary-coloured UI.
private func classColor(_ tc: TravelClass) -> Color {
    switch tc {
    case .economy: return Color(0xFF0EA5A0)
    // TravelClass.premiumEconomy => AppColors.info,
    case .business: return Color(0xFF8E5AD8)
    // TravelClass.first => AppColors.accent,
    }
}

/// A small pill showing the cabin class, tinted with its own colour.
/// Dart `_ClassBadge` — renamed so it cannot be confused with the shared
/// `ClassBadge` in TicketCardShell.swift.
private struct TripClassBadge: View {
    let travelClass: TravelClass

    var body: some View {
        let color = classColor(travelClass)
        Text(travelClass.label)
            .textStyle(AppTypography.body(11.5, weight: .w700, color: color))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .boxDecoration(color: color.withValues(alpha: 0.12), radius: 20)
    }
}

/// Dart `_SheetEndpoint`.
private struct SheetEndpoint: View {
    let time: String
    let code: String
    var name: String? = nil
    var alignEnd = false

    var body: some View {
        VStack(alignment: alignEnd ? .trailing : .leading, spacing: 0) {
            Text(time)
                .textStyle(AppTypography.heading(20, weight: .w800, color: AppColors.textPrimary))
            VGap(3)
            Text(code)
                .textStyle(AppTypography.body(12.5, weight: .w700, color: AppColors.textPrimary))
            if let name, !name.isEmpty {
                VGap(2)
                Text(name)
                    .textStyle(AppTypography.body(10.5, color: AppColors.textPrimary))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(alignEnd ? .trailing : .leading)
                    .frame(width: 92, alignment: alignEnd ? .trailing : .leading)
            }
        }
    }
}

/// A thin full-width dotted separator line used between the card's sections.
private struct DottedDivider: View {
    private static let dash: CGFloat = 3
    private static let gap: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            let count = min(max(Int((geometry.size.width / (Self.dash + Self.gap)).rounded(.down)), 0), 200)
            // MainAxisAlignment.spaceBetween.
            let spacing = count > 1
                ? (geometry.size.width - CGFloat(count) * Self.dash) / CGFloat(count - 1)
                : 0
            HStack(spacing: spacing) {
                ForEach(0..<count, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(dotColor)
                        .frame(width: Self.dash, height: 1.5)
                }
            }
        }
        .frame(height: 1.5)
    }
}

/// Flutter's `Wrap(spacing:, runSpacing:)`: children laid out left to right,
/// moving to a new run when the next one does not fit.
private struct WrapLayout: Layout {
    var spacing: CGFloat = 8
    var runSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(maxWidth: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = arrange(maxWidth: bounds.width, subviews: subviews).frames
        for (index, subview) in subviews.enumerated() {
            let frame = frames[index]
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(maxWidth: CGFloat, subviews: Subviews) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var width: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + runSpacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            width = max(width, x + size.width)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (frames, CGSize(width: width, height: y + rowHeight))
    }
}
