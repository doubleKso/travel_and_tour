// Port of lib/features/ticket/presentation/widgets/eticket_card.dart
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// The full branded e-ticket card.
///
/// This is the single source of truth for the e-ticket design: the
/// Booking-Confirmed screen (shown right after payment) and the Ticket Details
/// pop-up (reached from History) both render this widget, so the two can never
/// drift apart again. Entirely driven by a `TicketModel` so it can be shown
/// anywhere.
///
/// The content mirrors the web e-ticket: booking strip (airline, booked date,
/// booking reference, airline PNR, barcode), booked-by line, one card per
/// flight, then a card per passenger with their per-flight seat / bags /
/// status row.
///
/// The Dart widget computes its labels inline; here those computations are
/// `static` helpers on `ETicketCard` (same names as the Dart private members
/// where there was one) so the widget-test assertions can be ported as unit
/// tests.
struct ETicketCard: View {
    let ticket: TicketModel

    /// When true the "Important Information" section starts expanded instead of
    /// collapsed. Used where the legal text should be visible up front.
    let importantInfoAlwaysOpen: Bool

    /// When true a Payment Summary (fare, discount, total paid) is drawn under
    /// the passengers. The Ticket Details pop-up shows it; the Booking-Confirmed
    /// screen already has its own Amount Detail sheet.
    let showPaymentSummary: Bool

    /// Optional external owner of the Important Information expanded state, so
    /// an image capture of this card (Dart's `RepaintBoundary`) can reproduce
    /// what is on screen. Nil keeps the state inside the card, as in Dart.
    let importantInfoOpen: Binding<Bool>?

    @State private var showImportantInfoState: Bool

    init(
        ticket: TicketModel,
        importantInfoAlwaysOpen: Bool = false,
        showPaymentSummary: Bool = false,
        importantInfoOpen: Binding<Bool>? = nil
    ) {
        self.ticket = ticket
        self.importantInfoAlwaysOpen = importantInfoAlwaysOpen
        self.showPaymentSummary = showPaymentSummary
        self.importantInfoOpen = importantInfoOpen
        _showImportantInfoState = State(initialValue: importantInfoAlwaysOpen)
    }

    private var showImportantInfo: Bool {
        importantInfoOpen?.wrappedValue ?? showImportantInfoState
    }

    /// AnimatedSize (250 ms, easeOutCubic) around the body.
    private func toggleImportantInfo() {
        withAnimation(.timingCurve(0.215, 0.61, 0.355, 1, duration: 0.25)) {
            if let importantInfoOpen {
                importantInfoOpen.wrappedValue.toggle()
            } else {
                showImportantInfoState.toggle()
            }
        }
    }

    var body: some View {
        let t = ticket
        let hasReturn = t.inbound != nil

        VStack(alignment: .leading, spacing: 0) {
            // ── Branded green header ──────────────────────────────────────────
            header

            // ── Airline / booked / booking ref / airline PNR / barcode ───────
            BookingInfoPanel(ticket: t)
                .padding(16, 16, 16, 0)

            // ── Booked by ─────────────────────────────────────────────────────
            BookedBy(contactName: t.contactName)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16, 12, 16, 0)

            // ── Flight segments ───────────────────────────────────────────────
            VStack(spacing: 0) {
                FlightSegment(leg: t.outbound, isReturn: false)
                if hasReturn, let inbound = t.inbound {
                    VGap(12)
                    FlightSegment(leg: inbound, isReturn: true)
                }
            }
            .padding(16, 14, 16, 16)

            // Dotted separator between the flights and the passengers.
            DottedLine()

            // ── Passengers section ────────────────────────────────────────────
            passengersSection(t)

            // ── Payment summary ───────────────────────────────────────────────
            if showPaymentSummary {
                DottedLine()
                PaymentSummary(ticket: t)
            }

            MaterialDivider(height: 1, color: AppColors.dividerLight)

            // ── Important Information ─────────────────────────────────────────
            importantInfoSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .boxDecoration(
            color: AppColors.surface,
            radius: 20,
            shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: Offset(0, 4))]
        )
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left: Epic World white logo, width-capped so it doesn't crowd
            AppImage(AppAssets.brandLogo, height: 40, fit: .contain, tint: Colors.white)
                .frame(width: 90)
            // Center: E-Ticket label
            VStack(spacing: 0) {
                Text(LocaleKeys.ticket_e_ticket.tr())
                    .textStyle(AppTypography.heading(20, color: Colors.white))
                    .multilineTextAlignment(.center)
                VGap(2)
                Text(LocaleKeys.ticket_not_a_boarding_pass.tr())
                    .textStyle(AppTypography.body(10, color: Colors.white.withValues(alpha: 0.85)))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            // Right: IATA accredited-agent badge
            Group {
                if AppImage.image(for: AppAssets.brandLogoWhite) != nil {
                    AppImage(AppAssets.brandLogoWhite, height: 44, fit: .contain)
                } else {
                    // Dart's `errorBuilder` fallback.
                    AppImage(AppAssets.iataBadge, height: 44, fit: .contain)
                }
            }
            .frame(width: 72)
        }
        .padding(16, 14, 16, 14)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                stops: [
                    .init(color: AppColors.primaryDark, location: 0.0),
                    .init(color: AppColors.primary, location: 0.68),
                    .init(color: AppColors.accent, location: 1.0),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    // ── Passengers section ────────────────────────────────────────────────────

    /// How many traveller blocks to draw. The entered travellers win when the
    /// ticket carries them — a booking held for three people must print three,
    /// even if `seatCount` was recorded differently.
    static func passengerCount(_ t: TicketModel) -> Int {
        !t.passengers.isEmpty ? t.passengers.count : t.seatCount
    }

    private func passengersSection(_ t: TicketModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section title
            HStack(spacing: 0) {
                Icon(Icons.people_outline_rounded, size: 16, color: AppColors.textSecondary)
                HGap(6)
                Text(LocaleKeys.ticket_passengers.tr(args: ["\(Self.passengerCount(t))"]))
                    .textStyle(AppTypography.body(14, weight: .w700, color: AppColors.textSecondary, letterSpacing: 0.6))
            }
            VGap(12)
            // One block per traveller — from the entered travellers where the
            // ticket carries them, otherwise from the passenger-count choice.
            ForEach(0..<max(Self.passengerCount(t), 0), id: \.self) { i in
                if i > 0 { VGap(10) }
                passengerCard(t, i)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16, 14, 16, 16)
    }

    /// The traveller as they filled the form in. Nil on tickets issued before
    /// travellers were carried through, and on the mock catalogue — those fall
    /// back to the booking-level name and placeholders.
    static func traveller(_ t: TicketModel, _ index: Int) -> TicketPassenger? {
        index < t.passengers.count ? t.passengers[index] : nil
    }

    /// The airline's ticket number when the backend has reported one. Otherwise
    /// the booking reference, which is real and is what an agent can actually
    /// look the passenger up by — never a slice of a locally generated UUID
    /// dressed up to look like a ticket number.
    static func ticketNumber(_ t: TicketModel, _ index: Int) -> String {
        let traveller = Self.traveller(t, index)
        // Ticket ids can be short (History's mock bookings) or a 36-char UUID
        // (tickets issued at payment), so clamp the prefix instead of a fixed
        // substring(0, 11) — the latter throws a RangeError on the short ones.
        let idBase = t.id.count >= 11 ? String(t.id.prefix(11)) : t.id
        if let traveller, !traveller.ticketNumber.isEmpty { return traveller.ticketNumber }
        return !t.bookingReference.isEmpty
            ? "\(t.bookingReference)-\(index + 1)"
            : "\(idBase)\(index + 1)"
    }

    /// The name printed on a passenger card.
    static func passengerName(_ t: TicketModel, _ index: Int) -> String {
        if let traveller = Self.traveller(t, index), !traveller.fullName.isEmpty { return traveller.fullName }
        return t.passengerName
    }

    /// The passport when there is one, otherwise the NRC that domestic
    /// travellers give instead — the label of that line.
    static func documentLabel(passport: String, nrc: String) -> String {
        passport.isEmpty && !nrc.isEmpty
            ? LocaleKeys.booking_nrc.tr()
            : LocaleKeys.common_passport.tr()
    }

    // Builds a single passenger card. `index` is the zero-based passenger
    // position, so the number badge and ticket number differ per person.
    private func passengerCard(_ t: TicketModel, _ index: Int) -> some View {
        let traveller = Self.traveller(t, index)
        let ticketNumber = Self.ticketNumber(t, index)
        let passport = traveller?.passportNo ?? ""
        let nrc = traveller?.nrc ?? ""
        let phone = traveller?.phone ?? ""
        let name = Self.passengerName(t, index)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                Text("\(index + 1)")
                    .textStyle(AppTypography.body(13, weight: .w700, color: Colors.white))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(AppColors.primaryDark))
                HGap(12)
                VStack(alignment: .leading, spacing: 0) {
                    Text(name.uppercased())
                        .textStyle(AppTypography.body(15, weight: .w800, color: AppColors.textPrimary))
                        .lineLimit(2)
                        .truncationMode(.tail)
                    VGap(2)
                    Text(Self.passengerTypeLabel(traveller?.type).uppercased())
                        .textStyle(AppTypography.body(10.5, weight: .w700, color: AppColors.textTertiary, letterSpacing: 0.5))
                    VGap(10)
                    PassengerInfoLine(
                        icon: Icons.confirmation_number_outlined,
                        label: LocaleKeys.ticket_ticket.tr(),
                        value: ticketNumber
                    )
                    VGap(6)
                    // The passport when there is one, otherwise the NRC that
                    // domestic travellers give instead.
                    PassengerInfoLine(
                        icon: Icons.badge_outlined,
                        label: Self.documentLabel(passport: passport, nrc: nrc),
                        value: Self.masked(!passport.isEmpty ? passport : nrc)
                    )
                    VGap(6)
                    PassengerInfoLine(
                        icon: Icons.phone_outlined,
                        label: LocaleKeys.common_phone.tr(),
                        value: !phone.isEmpty ? phone : "—"
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            VGap(12)
            // Per-flight row: route / date / flight no., seat, bags, status.
            PassengerFlightRow(leg: t.outbound, confirmed: !t.isReservation)
            if let inbound = t.inbound {
                VGap(8)
                PassengerFlightRow(leg: inbound, confirmed: !t.isReservation)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .boxDecoration(color: AppColors.background, radius: 14, borderColor: AppColors.divider)
    }

    /// adult / child / infant as the fare was priced; anything unrecognised is
    /// an adult, which is what every traveller was before types were carried.
    static func passengerTypeLabel(_ type: String?) -> String {
        let value = type?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if value.hasPrefix("inf") { return LocaleKeys.ticket_infant.tr() }
        if value.hasPrefix("ch") { return LocaleKeys.ticket_child.tr() }
        return LocaleKeys.ticket_adult.tr()
    }

    /// Shows only the last four characters of a travel document, as the web
    /// e-ticket does, so a shared or saved ticket doesn't expose the full number.
    static func masked(_ document: String) -> String {
        let value = document.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return "—" }
        if value.count <= 4 { return value }
        return "••••\(value.suffix(4))"
    }

    // ── Important Information (expandable) ───────────────────────────────────

    private var importantInfoSection: some View {
        VStack(spacing: 0) {
            Button {
                toggleImportantInfo()
            } label: {
                HStack(spacing: 0) {
                    Icon(Icons.info_outline_rounded, size: 17, color: AppColors.textSecondary)
                    HGap(8)
                    Text(LocaleKeys.ticket_important_information.tr())
                        .textStyle(AppTypography.body(12, weight: .w700, color: AppColors.textSecondary, letterSpacing: 0.6))
                    Spacer(minLength: 0)
                    Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: AppColors.textSecondary)
                        .rotationEffect(.degrees(showImportantInfo ? 180 : 0))
                        .animation(.linear(duration: 0.2), value: showImportantInfo)
                }
                .padding(16, 14, 14, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // AnimatedSize: the body appears / goes at once and the height
            // animates, clipped to the card.
            VStack(spacing: 0) {
                if showImportantInfo {
                    ImportantInfoBody()
                        .transition(.identity)
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: 0)
                        .transition(.identity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .clipped()
        }
    }

    // ── Static label helpers (inline computations in the Dart widgets) ──────

    /// A round trip on two carriers names both (`_BookingInfoPanel`).
    static func airlines(_ t: TicketModel) -> String {
        var candidates = [t.outbound.operatorName.trimmingCharacters(in: .whitespacesAndNewlines)]
        if let inbound = t.inbound {
            candidates.append(inbound.operatorName.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        // Dart set literal: insertion-ordered and unique.
        var names: [String] = []
        for name in candidates where !names.contains(name) {
            names.append(name)
        }
        return names.filter { !$0.isEmpty }.joined(separator: " / ")
    }

    /// `_FlightSegment._place`.
    static func place(_ name: String, _ code: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty ? trimmed : code
    }

    /// The flight strip's route title (`_FlightSegment`).
    static func segmentRoute(_ leg: TripOptionModel) -> String {
        "\(place(leg.originName, leg.originCode)) → \(place(leg.destinationName, leg.destinationCode))"
    }

    /// Flight number and aircraft (`_FlightSegment.flightLine`).
    static func flightLine(_ leg: TripOptionModel) -> String {
        [leg.flightNumber, leg.aircraft]
            .compactMap { $0 }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " · ")
    }

    /// Stops label of a leg.
    static func stopsLabel(_ leg: TripOptionModel) -> String {
        leg.isDirect ? "Non-stop" : "\(leg.stops) stop\(leg.stops > 1 ? "s" : "")"
    }

    /// Airlines send either a bare `2` or a full `Terminal 2`
    /// (`_SegmentEndpoint._terminalLabel`).
    static func terminalLabel(_ value: String) -> String {
        value.range(of: #"^\d+[A-Za-z]?$"#, options: .regularExpression) != nil ? "Terminal \(value)" : value
    }

    /// Route · date · flight number of a passenger's flight row.
    static func passengerFlightRoute(_ leg: TripOptionModel) -> String {
        let flightNo = leg.flightNumber?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var parts = [
            "\(leg.originCode) → \(leg.destinationCode)",
            DateFormat("d MMM").format(leg.departure),
        ]
        if !flightNo.isEmpty { parts.append(flightNo) }
        return parts.joined(separator: " · ")
    }

    /// Checked bags of a passenger's flight row.
    static func bags(_ leg: TripOptionModel) -> String {
        (leg.baggageKg ?? 0) > 0 ? "\(leg.baggageKg ?? 0) kg" : "—"
    }

    /// What the booking cost (`_PaymentSummary`): the fare, any checkout
    /// discount, and the amount actually charged. The fare is rebuilt from the
    /// paid total plus the discount, so the lines always add back up to what
    /// was paid.
    static func paymentSummary(_ t: TicketModel) -> (promotion: Double, otherDiscount: Double, fare: Double, promoLabel: String) {
        let promotion = t.promotion > 0 ? t.promotion : 0.0
        // Whatever else came off at checkout besides the promo (reward points).
        let otherDiscount = t.discount > promotion ? t.discount - promotion : 0.0
        let fare = t.totalPaid + promotion + otherDiscount
        // History's booking records keep the promo's amount but not its code.
        let promoLabel = !t.promoCode.isEmpty
            ? "\(LocaleKeys.booking_promo_code.tr()) (\(t.promoCode))"
            : LocaleKeys.booking_promo_code.tr()
        return (promotion, otherDiscount, fare, promoLabel)
    }
}

// ── Booking info panel ────────────────────────────────────────────────────────

/// Airline, booked date, Epic World's booking reference, the airline's PNR and
/// the barcode — the strip at the top of the web e-ticket.
private struct BookingInfoPanel: View {
    let ticket: TicketModel

    var body: some View {
        let t = ticket
        // A round trip on two carriers names both.
        let airlines = ETicketCard.airlines(t)

        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                InfoCell(
                    label: LocaleKeys.ticket_airline.tr(),
                    value: !airlines.isEmpty ? airlines.uppercased() : "—"
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                HGap(12)
                InfoCell(
                    label: LocaleKeys.common_booked.tr(),
                    value: DateFormat("d MMM yyyy").format(t.issuedAt)
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            VGap(12)
            HStack(alignment: .top, spacing: 0) {
                InfoCell(
                    label: LocaleKeys.ticket_booking_reference.tr(),
                    value: !t.bookingReference.isEmpty ? t.bookingReference : "—"
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                HGap(12)
                InfoCell(
                    label: LocaleKeys.ticket_airline_pnr.tr(),
                    value: !t.pnr.isEmpty ? t.pnr : "—",
                    valueColor: AppColors.primaryDark
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            VGap(14)
            BarcodeWidget(
                data: !t.bookingReference.isEmpty ? t.bookingReference : t.id,
                color: AppColors.textPrimary
            )
            .frame(width: 220, height: 44)
        }
        .frame(maxWidth: .infinity)
        .padding(14, 14, 14, 12)
        .boxDecoration(color: AppColors.background, radius: 14, borderColor: AppColors.divider)
    }
}

/// A small upper-case label over its bold value, used by the booking strip.
private struct InfoCell: View {
    let label: String
    let value: String
    var valueColor: Color = AppColors.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label.uppercased())
                .textStyle(AppTypography.body(10, weight: .w600, color: AppColors.textTertiary, letterSpacing: 0.5))
            VGap(3)
            Text(value)
                .textStyle(AppTypography.body(13, weight: .w700, color: valueColor, letterSpacing: 0.3))
                .lineLimit(2)
                .truncationMode(.tail)
        }
    }
}

// ── Booked by ─────────────────────────────────────────────────────────────────

/// "Booked by Epic World Co., Ltd. · (contact name)" over the branch phone
/// line.
private struct BookedBy: View {
    let contactName: String

    var body: some View {
        let muted = AppTypography.body(12, color: AppColors.textSecondary)
        let strong = AppTypography.body(12, weight: .w600, color: AppColors.textPrimary)
        VStack(alignment: .leading, spacing: 0) {
            (Text("\(LocaleKeys.ticket_booked_by.tr()) ").styled(muted)
                + Text(LocaleKeys.ticket_epic_world_co_ltd.tr()).styled(strong)
                + Text(contactName.isEmpty ? "" : " · \(contactName)").styled(muted))
            VGap(4)
            (Text("\(LocaleKeys.ticket_main_branch.tr()) ").styled(muted)
                + Text("+95 9 787 844 882").styled(strong))
        }
    }
}

// ── Flight segment ────────────────────────────────────────────────────────────

/// One leg: the route and fare chips on a green strip, then the date, flight
/// number / aircraft, both airports with their times, and the terminals when
/// the airline reported them.
private struct FlightSegment: View {
    let leg: TripOptionModel
    let isReturn: Bool

    var body: some View {
        let fareBrand = leg.fareBrand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let flightLine = ETicketCard.flightLine(leg)

        VStack(spacing: 0) {
            // Route + cabin / fare-brand chips.
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Icon(isReturn ? Icons.flight_land : Icons.flight_takeoff, size: 16, color: AppColors.primary)
                    HGap(8)
                    Text(ETicketCard.segmentRoute(leg))
                        .textStyle(AppTypography.body(13.5, weight: .w700, color: AppColors.textPrimary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                VGap(8)
                ETicketWrapLayout(spacing: 6, runSpacing: 6) {
                    Chip(label: leg.travelClass.label, color: AppColors.primaryDark)
                    if !fareBrand.isEmpty {
                        Chip(label: fareBrand, color: AppColors.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12, 10, 12, 10)
            .background(AppColors.primarySurface)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text(DateFormat("EEEE, d MMM yyyy").format(leg.departure))
                        .textStyle(AppTypography.body(12, weight: .w600, color: AppColors.textPrimary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !flightLine.isEmpty {
                        HGap(8)
                        Text(flightLine)
                            .textStyle(AppTypography.body(11.5, color: AppColors.textSecondary))
                    }
                }
                VGap(12)
                HStack(alignment: .center, spacing: 0) {
                    SegmentEndpoint(
                        code: leg.originCode,
                        time: leg.departure,
                        terminal: leg.departureTerminal,
                        alignEnd: false
                    )
                    TicketRouteMiddle(
                        isFlight: true,
                        duration: Formatters.duration(leg.duration),
                        stops: ETicketCard.stopsLabel(leg)
                    )
                    .frame(maxWidth: .infinity)
                    SegmentEndpoint(
                        code: leg.destinationCode,
                        time: leg.arrival,
                        terminal: leg.arrivalTerminal,
                        alignEnd: true
                    )
                }
            }
            .padding(12, 12, 12, 14)
        }
        .frame(maxWidth: .infinity)
        .boxDecoration(color: AppColors.surface, radius: 14, borderColor: AppColors.border)
    }
}

/// An airport code over its time, and the terminal beneath when known.
private struct SegmentEndpoint: View {
    let code: String
    let time: DateTime
    let terminal: String?
    let alignEnd: Bool

    var body: some View {
        let terminal = self.terminal?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        VStack(alignment: alignEnd ? .trailing : .leading, spacing: 0) {
            Text(code)
                .textStyle(AppTypography.heading(24, weight: .w800, color: AppColors.textPrimary))
            VGap(2)
            Text(Formatters.eTicketTime(time))
                .textStyle(AppTypography.body(14, weight: .w700, color: AppColors.textPrimary))
            if !terminal.isEmpty {
                VGap(2)
                Text(ETicketCard.terminalLabel(terminal))
                    .textStyle(AppTypography.body(10.5, color: AppColors.textSecondary))
            }
        }
    }
}

/// An outlined pill — cabin class and fare brand on the flight strip.
private struct Chip: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .textStyle(AppTypography.body(11, weight: .w600, color: color))
            .padding(horizontal: 10, vertical: 3)
            .boxDecoration(color: AppColors.surface, radius: 20, borderColor: AppColors.border)
    }
}

// ── Passenger details ─────────────────────────────────────────────────────────

private struct PassengerInfoLine: View {
    let icon: IconData
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Icon(icon, size: 14, color: AppColors.accent)
            HGap(6)
            Text("\(label):")
                .textStyle(AppTypography.body(12, color: AppColors.textSecondary))
            HGap(6)
            Text(value)
                .textStyle(AppTypography.body(12.5, weight: .w600, color: AppColors.primaryDark))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// One flight on a passenger's card: route · date · flight number over the
/// seat, checked bags and booking status.
private struct PassengerFlightRow: View {
    let leg: TripOptionModel
    let confirmed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(ETicketCard.passengerFlightRoute(leg))
                .textStyle(AppTypography.body(12.5, weight: .w700, color: AppColors.textPrimary))
            VGap(8)
            ETicketWrapLayout(spacing: 14, runSpacing: 6, crossAxisCenter: true) {
                // Seats are assigned by the airline at check-in.
                LabelledValue(
                    label: LocaleKeys.ticket_seat.tr(),
                    value: LocaleKeys.ticket_at_check_in.tr()
                )
                LabelledValue(
                    label: LocaleKeys.ticket_checked_bags.tr(),
                    value: ETicketCard.bags(leg)
                )
                if confirmed {
                    Text(LocaleKeys.ticket_confirmed.tr())
                        .textStyle(AppTypography.body(10.5, weight: .w700, color: AppColors.success))
                        .padding(horizontal: 9, vertical: 3)
                        .boxDecoration(color: AppColors.success.withValues(alpha: 0.12), radius: 20)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12, 10, 12, 10)
        .boxDecoration(color: AppColors.surface, radius: 10, borderColor: AppColors.border)
    }
}

/// A muted label followed by its bold value, on one line.
private struct LabelledValue: View {
    let label: String
    let value: String

    var body: some View {
        Text("\(label) ").styled(AppTypography.body(11, color: AppColors.textSecondary))
            + Text(value).styled(AppTypography.body(11.5, weight: .w700, color: AppColors.textPrimary))
    }
}

// ── Payment summary ───────────────────────────────────────────────────────────

/// What the booking cost: the fare, any checkout discount, and the amount
/// actually charged. The fare is rebuilt from the paid total plus the
/// discount, so the lines always add back up to what was paid.
private struct PaymentSummary: View {
    let ticket: TicketModel

    var body: some View {
        let t = ticket
        let summary = ETicketCard.paymentSummary(t)
        let promotion = summary.promotion
        let otherDiscount = summary.otherDiscount
        let fare = summary.fare

        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // Section title
                HStack(spacing: 0) {
                    Icon(Icons.receipt_long_outlined, size: 16, color: AppColors.textSecondary)
                    HGap(6)
                    Text(LocaleKeys.ticket_payment_summary.tr())
                        .textStyle(AppTypography.body(14, weight: .w700, color: AppColors.textSecondary, letterSpacing: 0.6))
                }
                VGap(14)
                SummaryLine(
                    label: LocaleKeys.ticket_fare.tr(),
                    value: Formatters.price(fare, t.currency)
                )
                if promotion > 0 || otherDiscount > 0 {
                    VGap(12)
                    DottedLine()
                    VGap(12)
                    SummaryLine(
                        label: LocaleKeys.ticket_total_before_discounts.tr(),
                        value: Formatters.price(fare, t.currency),
                        weight: .w700
                    )
                    if promotion > 0 {
                        VGap(10)
                        SummaryLine(
                            label: summary.promoLabel,
                            value: "− \(Formatters.price(promotion, t.currency))",
                            color: AppColors.success,
                            weight: .w600
                        )
                    }
                    if otherDiscount > 0 {
                        VGap(10)
                        SummaryLine(
                            label: LocaleKeys.booking_discount.tr(),
                            value: "− \(Formatters.price(otherDiscount, t.currency))",
                            color: AppColors.success,
                            weight: .w600
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16, 14, 16, 14)

            // Total paid — tinted band so the amount charged stands out.
            HStack(spacing: 0) {
                Text(LocaleKeys.ticket_total_paid.tr())
                    .textStyle(AppTypography.body(14, weight: .w700, color: AppColors.textPrimary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                HGap(12)
                Text(Formatters.price(t.totalPaid, t.currency))
                    .textStyle(AppTypography.heading(20, weight: .w800, color: AppColors.primaryDark))
            }
            .padding(16, 14, 16, 14)
            .frame(maxWidth: .infinity)
            .background(AppColors.primarySurface)
        }
    }
}

/// One label ↔ amount line of the payment summary.
private struct SummaryLine: View {
    let label: String
    let value: String
    var color: Color = AppColors.textPrimary
    var weight: FontWeight = .w500

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(label)
                .textStyle(AppTypography.body(13, weight: weight, color: color))
                .frame(maxWidth: .infinity, alignment: .leading)
            HGap(12)
            Text(value)
                .textStyle(AppTypography.body(13, weight: .w700, color: color))
        }
    }
}

// ── Important Information body ────────────────────────────────────────────────

private struct ImportantInfoBody: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            InfoSection(
                title: LocaleKeys.ticket_ticket.tr(),
                body: "This ticket is non-transferable and valid on airline flights only."
            )
            InfoSection(
                title: LocaleKeys.ticket_reconfirmation_date_change.tr(),
                body: "Subject to booking conditions, refer to the airline's Terms & Conditions."
            )
            InfoSection(
                title: LocaleKeys.ticket_check_in.tr(),
                body: "International [Except Guangzhou (CAN)]: Check-in counter opens 3 hours & closes 45 minutes before departure. Guangzhou (CAN): opens 3 hours & closes 1 hour before departure. Boarding gate opens 1 hour 15 minutes & closes 10 minutes before departure.\n\n"
                    + "Domestic — ATR72-600: Check-in opens 2 hours & closes 30 minutes before departure. E190/A319/A320: Check-in opens 2 hours 30 minutes & closes 30 minutes before departure. Boarding gate opens 1 hour 15 minutes & closes 10 minutes before departure.\n\n"
                    + "Important Note: Airline will not be responsible for late reporting of passengers."
            )
            InfoSection(
                title: LocaleKeys.ticket_traveling_documents.tr(),
                body: "Travellers must ensure that their passport, health requirements, visas & other necessary documents are valid and meet the immigration requirements at the departure and destination airports. Passengers should carry a copy of this booking confirmation while travelling."
            )
            InfoSection(
                title: LocaleKeys.ticket_use_of_flight_coupons_and_sequence.tr(),
                body: "The flight coupons must be used in the sequence printed in the passenger coupon of the ticket. Out-of-sequence travel is not allowed. If a passenger changes the itinerary, the airline will determine the fares based on the new itinerary."
            )
            InfoSection(
                title: LocaleKeys.ticket_no_show_policy.tr(),
                body: "Reporting late or failing to travel on the booked flight will be considered a No-Show, and the relevant penalties as per fare rules will be applied to re-booking or refunding."
            )
            InfoSection(
                title: LocaleKeys.ticket_online_ticket_policy.tr(),
                body: "To board a domestic flight, passengers who purchased the ticket from the airline's official website (maiair.com) or other online booking channels using credit or debit cards are requested to present the respective card(s) used to buy the ticket at the airport during check-in."
            )
            InfoSection(
                title: LocaleKeys.ticket_refund_policy.tr(),
                body: "Subject to the airline's refund rules, the airline will only refund the fare of the unused sector and Passenger Fuel Surcharge after deducting applicable cancellation and/or no-show fees. Passengers must bear any applicable fees/charges, including payment gateway and card issuer charges."
            )
            InfoSection(
                title: LocaleKeys.ticket_conditions_of_carriage.tr(),
                body: "Carriage and other services provided by the airline are subject to the airline's Conditions of Carriage, which are incorporated by reference. The Conditions of Carriage may be obtained from the issuing airline."
            )
            InfoSection(
                title: LocaleKeys.ticket_power_bank_restrictions.tr(),
                body: "Passengers are strictly prohibited from using and charging power banks during flight. Only two (2) power banks up to 100Wh, or one (1) power bank of 100Wh–160Wh, may be carried per passenger and must be transported in carry-on baggage."
            )
            InfoSection(
                title: LocaleKeys.ticket_data_protection_policy.tr(),
                body: "Passenger data is processed per the privacy policy of the applicable airline's reservation system provider (\"PSS\") or relevant distribution channel(s) where the booking is made."
            )
            InfoSection(
                title: LocaleKeys.ticket_checked_free_baggage_allowance_fba.tr(),
                body: "Domestic — All Sectors:\n"
                    + "• Business: 30KG (max. 2 pieces & not exceeding 30KG per piece)\n"
                    + "• Economy: 20KG (max. 2 pieces & not exceeding 20KG per piece)\n"
                    + "• Infant: 10KG (max. 1 piece & not exceeding 10KG per piece) · Size limit: 56cm × 36cm × 22cm\n\n"
                    + "Important Note: Refer to the Baggage Allowance at E-Ticket receipt for eligible FBA."
            )
            InfoSection(
                title: LocaleKeys.ticket_cabin_carry_on_baggage.tr(),
                body: "Domestic — 7KG (max. 1 piece & not exceeding 7KG per piece) · Size limit: 56cm × 36cm × 22cm"
            )
            InfoSection(
                title: LocaleKeys.ticket_paid_add_ons.tr(),
                body: "Flight-related: Extra Baggage, Seat Selection, Meal Selection\n"
                    + "Ground-related: Mai Hsoong Kha Services VIP Service & Wheelchair Service\n"
                    + "Paid e-visa services are also available.",
                isLast: true
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16, 2, 16, 18)
    }
}

private struct InfoSection: View {
    let title: String
    /// Dart's `body` (renamed: `body` is the SwiftUI view requirement).
    let bodyText: String
    var isLast = false

    init(title: String, body: String, isLast: Bool = false) {
        self.title = title
        self.bodyText = body
        self.isLast = isLast
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title on its own line for a clear, scannable hierarchy.
            HStack(alignment: .center, spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.primary)
                    .frame(width: 3, height: 13)
                HGap(8)
                Text(title)
                    .textStyle(AppTypography.body(12.5, weight: .w700, color: AppColors.textPrimary))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            VGap(6)
            // Body: muted, roomy line-height for easy reading.
            Text(bodyText)
                .textStyle(AppTypography.body(12, color: AppColors.textSecondary, height: 1.55))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 11)
        }
        .padding(.bottom, isLast ? 0 : 18)
    }
}

// ── Wrap ──────────────────────────────────────────────────────────────────────

/// Flutter's `Wrap` (start-aligned runs), for the chips and the passenger
/// flight row.
private struct ETicketWrapLayout: Layout {
    var spacing: CGFloat = 0
    var runSpacing: CGFloat = 0
    /// `WrapCrossAlignment.center`.
    var crossAxisCenter = false

    private struct Run {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func runs(_ maxWidth: CGFloat, _ sizes: [CGSize]) -> [Run] {
        var runs: [Run] = []
        var current = Run()
        for (index, size) in sizes.enumerated() {
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if !current.indices.isEmpty && needed > maxWidth {
                runs.append(current)
                current = Run()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { runs.append(current) }
        return runs
    }

    private func sizes(_ maxWidth: CGFloat, _ subviews: Subviews) -> [CGSize] {
        subviews.map { $0.sizeThatFits(ProposedViewSize(width: maxWidth.isFinite ? maxWidth : nil, height: nil)) }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let laidOut = runs(maxWidth, sizes(maxWidth, subviews))
        let width = laidOut.map(\.width).max() ?? 0
        let height = laidOut.map(\.height).reduce(0, +) + runSpacing * CGFloat(max(laidOut.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        let measured = sizes(maxWidth, subviews)
        var y = bounds.minY
        for run in runs(maxWidth, measured) {
            var x = bounds.minX
            for index in run.indices {
                let size = measured[index]
                let dy = crossAxisCenter ? (run.height - size.height) / 2 : 0
                subviews[index].place(
                    at: CGPoint(x: x, y: y + dy),
                    proposal: ProposedViewSize(width: size.width, height: size.height)
                )
                x += size.width + spacing
            }
            y += run.height + runSpacing
        }
    }
}

// ── Barcode (barcode_widget) ──────────────────────────────────────────────────

/// Code 128 module patterns from CoreImage — the part of `barcode_widget`'s
/// `Barcode.code128()` the e-ticket card and its PDF use. Not in the
/// foundation, so it lives with its only users.
enum Barcode {
    private static let context = CIContext(options: [.useSoftwareRenderer: false])
    private static var cache: [String: [Bool]] = [:]
    private static let lock = NSLock()

    /// One entry per module, left to right: true for a bar. Empty when `data`
    /// cannot be encoded (Code 128 is ASCII only).
    static func code128Bars(_ data: String) -> [Bool] {
        lock.lock()
        if let cached = cache[data] { lock.unlock(); return cached }
        lock.unlock()

        guard let message = data.data(using: .ascii), !data.isEmpty else { return [] }
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = message
        filter.quietSpace = 0
        filter.barcodeHeight = 1
        guard let output = filter.outputImage,
              let image = context.createCGImage(output, from: output.extent) else { return [] }

        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return [] }
        var pixels = [UInt8](repeating: 255, count: width * height)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let bitmap = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            bitmap.interpolationQuality = .none
            bitmap.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return [] }
        let row = height / 2
        let bars = (0..<width).map { pixels[row * width + $0] < 128 }

        lock.lock()
        cache[data] = bars
        lock.unlock()
        return bars
    }
}

/// `BarcodeWidget(barcode: Barcode.code128(), data: …, drawText: false, color: …)`:
/// the bars stretched across the frame it is given.
struct BarcodeWidget: View {
    let data: String
    var color: Color = Colors.black

    var body: some View {
        let bars = Barcode.code128Bars(data)
        Canvas { context, size in
            guard !bars.isEmpty else { return }
            let module = size.width / CGFloat(bars.count)
            var path = Path()
            var index = 0
            while index < bars.count {
                guard bars[index] else { index += 1; continue }
                var end = index
                while end < bars.count && bars[end] { end += 1 }
                path.addRect(CGRect(
                    x: CGFloat(index) * module,
                    y: 0,
                    width: CGFloat(end - index) * module,
                    height: size.height
                ))
                index = end
            }
            context.fill(path, with: .color(color))
        }
    }
}
