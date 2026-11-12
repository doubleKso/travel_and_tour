// Port of lib/features/booking/presentation/pages/booking_confirmation_page.dart
import SwiftUI

/// Reservation state displayed after `holdFlight` succeeds and before payment.
/// The values all come from the live hold response and the form data captured
/// in the preceding traveller-details screen.
///
/// Embedded by `BookingDetailPage` while the booking stage is `.confirmation`
/// (it is not a route of its own), exactly as the Dart page embeds it.
struct BookingConfirmationContent: View {
    let booking: FlightBookingState
    let onBack: () -> Void

    /// Abandons the checkout altogether: the hold and everything entered are
    /// discarded and the customer lands back on the Home tab, exactly as
    /// leaving the payment screen does.
    let onLeave: () -> Void
    let onContinueToPayment: () -> Void

    // `_BookingConfirmationPageState`
    @State private var deadline: DateTime? = nil
    @State private var remaining: Duration = .zero
    @State private var didInitState = false

    init(
        booking: FlightBookingState,
        onBack: @escaping () -> Void,
        onLeave: @escaping () -> Void,
        onContinueToPayment: @escaping () -> Void
    ) {
        self.booking = booking
        self.onBack = onBack
        self.onLeave = onLeave
        self.onContinueToPayment = onContinueToPayment
    }

    var body: some View {
        content
            .onAppear(perform: initState)
            // Timer.periodic(1s) — cancelled with the view, as `dispose` does.
            .task { await runCountdown() }
    }

    // MARK: - State

    private func initState() {
        guard !didInitState else { return }
        didInitState = true
        let hold = booking.holdResponse
        let value: String?
        if let hold, !hold.ticketTimeLimitLocal.isEmpty {
            value = hold.ticketTimeLimitLocal
        } else {
            value = hold?.ticketTimeLimit
        }
        if let value, !value.isEmpty {
            deadline = DateTime.tryParse(value)
        } else {
            deadline = nil
        }
        refreshCountdown()
    }

    private func runCountdown() async {
        initState()
        guard deadline != nil else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { break }
            refreshCountdown()
        }
    }

    private func refreshCountdown() {
        guard let deadline else { return }
        let left = deadline.difference(DateTime.now())
        remaining = left.isNegative ? .zero : left
    }

    /// Asks before abandoning the reservation.
    ///
    /// Leaving releases the seat hold and drops everything entered on the way
    /// here, so the back gesture and the header's back arrow both route through
    /// this rather than popping straight out.
    private func confirmLeaveConfirmation() async {
        let leave: Bool? = await showDialog(
            barrierDismissible: false,
            barrierColor: Color(0x33000000)
        ) { _ in
            IosConfirmDialog(
                title: LocaleKeys.booking_leave_confirmation_title.tr(),
                message: LocaleKeys.booking_leave_confirmation_message.tr(),
                confirmLabel: LocaleKeys.common_yes.tr(),
                cancelLabel: LocaleKeys.common_no.tr()
            )
        }
        guard leave == true else { return }

        // Yes → out of the checkout entirely, back to the Home tab.
        onLeave()
    }

    // MARK: - Build

    @ViewBuilder
    private var content: some View {
        if let hold = booking.holdResponse,
           let request = booking.holdRequest,
           let outbound = booking.selectedOutbound {
            confirmation(hold: hold, request: request, outbound: outbound)
        } else {
            Scaffold(backgroundColor: AppColors.background) {
                Button(action: onBack) {
                    Text("Reservation details are unavailable.")
                        .textStyle(AppTypography.labelLarge.copyWith(color: AppColors.primary))
                }
                .buttonStyle(TextButtonStyle())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func confirmation(
        hold: FlightHoldResponse,
        request: FlightHoldRequest,
        outbound: TripOptionModel
    ) -> some View {
        let total = hold.total > 0 ? hold.total : booking.totalPrice
        let currency = !hold.currency.isEmpty ? hold.currency : outbound.currency
        let contactName = Dart.str(request.contact["fullName"])?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return Scaffold(backgroundColor: AppColors.background) {
            VStack(spacing: 0) {
                CheckoutStepHeader(
                    stage: .confirmation,
                    fromCode: booking.fromLocation.code,
                    toCode: booking.toLocation.code,
                    subtitle: "\(Formatters.shortDate(booking.departDate))  ·  "
                        + "\(booking.totalTravellers) "
                        + (booking.totalTravellers == 1 ? "Traveller" : "Travellers"),
                    onBack: { Task { await confirmLeaveConfirmation() } }
                )
                ScrollView {
                    VStack(spacing: 0) {
                        reservationHeader
                        VGap(12)
                        referenceCard(hold.reference, hold.pnr)
                        VGap(12)
                        paymentDeadline(deadline)
                        VGap(12)
                        tripCard(
                            legs: hold.legs,
                            outbound: outbound,
                            inbound: booking.selectedInbound,
                            passengerName: contactName?.isEmpty == false ? contactName! : "Traveller"
                        )
                        VGap(12)
                        totalCard(
                            total,
                            currency,
                            hold.passengers > 0 ? hold.passengers : booking.totalTravellers
                        )
                    }
                    .padding(AppSpacing.screenH, 10, AppSpacing.screenH, 18)
                }
                .frame(maxHeight: .infinity)
                bottomActions
            }
        }
        // The pop is intercepted so the back gesture and the header arrow
        // both ask before the hold is thrown away; stepping back out is
        // done by the handler.
        .popScope(canPop: false) { didPop in
            if didPop { return }
            Task { await confirmLeaveConfirmation() }
        }
    }

    private var reservationHeader: some View {
        HStack(spacing: 0) {
            // CircleAvatar(radius: 15)
            Icon(Icons.check_rounded, size: 19, color: Colors.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color(0xFF09B576)))
            HGap(11)
            VStack(alignment: .leading, spacing: 0) {
                Text("Your seats are reserved")
                    .textStyle(AppTypography.body(14, weight: .w700, color: AppColors.textPrimary))
                VGap(2)
                Text("Nothing has been charged yet.")
                    .textStyle(AppTypography.body(12, color: AppColors.textSecondary))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("Payment pending")
                .textStyle(AppTypography.body(9, weight: .w700, color: Color(0xFFA76B00)))
                .padding(horizontal: 9, vertical: 4)
                .boxDecoration(color: Color(0xFFFFEBC0), radius: 10)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .boxDecoration(color: Color(0xFFEAF8F1), radius: 14)
    }

    private func referenceCard(_ reference: String, _ pnr: String) -> some View {
        card {
            HStack(spacing: 0) {
                referenceColumn("BOOKING REFERENCE", reference.isEmpty ? "—" : reference)
                Rectangle()
                    .fill(AppColors.border)
                    .frame(width: 1, height: 55)
                referenceColumn("AIRLINE PNR", pnr.isEmpty ? "—" : pnr, green: true)
            }
        }
    }

    private func referenceColumn(_ label: String, _ value: String, green: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .textStyle(AppTypography.body(9, weight: .w700, color: AppColors.textPrimary))
            VGap(5)
            Text(value)
                .textStyle(AppTypography.heading(16, color: green ? AppColors.success : AppColors.textPrimary))
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func paymentDeadline(_ deadline: DateTime?) -> some View {
        card(leftAccent: true) {
            HStack(spacing: 0) {
                Icon(Icons.access_time_rounded, size: 20, color: Color(0xFFFFA000))
                HGap(10)
                VStack(alignment: .leading, spacing: 0) {
                    Text(
                        deadline == nil
                            ? "Complete payment before your reservation expires"
                            : "Complete payment before \(DateFormat("d MMM, h:mm a").format(deadline!.toLocal()))"
                    )
                    .textStyle(AppTypography.body(12, weight: .w700, color: AppColors.textPrimary))
                    VGap(3)
                    Text("After that the airline releases your seats automatically.")
                        .textStyle(AppTypography.body(10.5, color: AppColors.textSecondary))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if deadline != nil {
                    HGap(8)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(countdownText)
                            .textStyle(AppTypography.heading(19, color: AppColors.textPrimary))
                        Text("TIME LEFT")
                            .textStyle(AppTypography.body(8.5, weight: .w700, color: AppColors.textPrimary))
                    }
                }
            }
        }
    }

    private var countdownText: String {
        let hours = Self.padLeft2(remaining.inHours)
        let minutes = Self.padLeft2(remaining.inMinutes % 60)
        let seconds = Self.padLeft2(remaining.inSeconds % 60)
        return "\(hours):\(minutes):\(seconds)"
    }

    private static func padLeft2(_ value: Int) -> String {
        let text = String(value)
        return text.count >= 2 ? text : String(repeating: "0", count: 2 - text.count) + text
    }

    private func tripCard(
        legs: [FlightHoldLeg],
        outbound: TripOptionModel,
        inbound: TripOptionModel?,
        passengerName: String
    ) -> some View {
        card {
            VStack(alignment: .leading, spacing: 0) {
                Text("Your trip")
                    .textStyle(AppTypography.heading(16, color: AppColors.textPrimary))
                VGap(12)
                if !legs.isEmpty {
                    ForEach(legs.indices, id: \.self) { i in
                        if i > 0 { VGap(8) }
                        heldLeg(legs[i], i == 0 ? "DEPART" : "RETURN")
                    }
                } else {
                    leg(outbound, "DEPART")
                    if let inbound {
                        VGap(8)
                        leg(inbound, "RETURN")
                    }
                }
                MaterialDivider(height: 26, color: AppColors.border)
                Text("TRAVELLERS")
                    .textStyle(AppTypography.body(9, weight: .w700, color: AppColors.textPrimary))
                VGap(4)
                Text(passengerName)
                    .textStyle(AppTypography.body(13, color: AppColors.textPrimary))
            }
        }
    }

    private func legBadge(_ label: String) -> some View {
        Text(label)
            .textStyle(AppTypography.body(8, weight: .w700, color: Colors.white))
            .padding(horizontal: 6, vertical: 3)
            .boxDecoration(color: AppColors.success, radius: 4)
    }

    private func leg(_ leg: TripOptionModel, _ label: String) -> some View {
        HStack(spacing: 0) {
            legBadge(label)
            HGap(9)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(leg.originCode) → \(leg.destinationCode)")
                    .textStyle(AppTypography.body(13.5, weight: .w700, color: AppColors.textPrimary))
                Text("\(Formatters.shortDate(leg.departure)) · \(leg.flightNumber ?? leg.operatorName)")
                    .textStyle(AppTypography.body(10.5, color: AppColors.textPrimary))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            flightTime("\(Formatters.time12(leg.departure)) – \(Formatters.time12(leg.arrival))")
        }
        .padding(11)
        .frame(maxWidth: .infinity)
        .boxDecoration(color: Color(0xFFF7F8F8), radius: 10)
    }

    private func heldLeg(_ leg: FlightHoldLeg, _ label: String) -> some View {
        HStack(spacing: 0) {
            legBadge(label)
            HGap(9)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(leg.from) → \(leg.to)")
                    .textStyle(AppTypography.body(13.5, weight: .w700, color: AppColors.textPrimary))
                Text("\(holdLegDate(leg.date)) · \(leg.flightNo)")
                    .textStyle(AppTypography.body(10.5, color: AppColors.textPrimary))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            flightTime("\(leg.departTime) – \(leg.arriveTime)")
        }
        .padding(11)
        .frame(maxWidth: .infinity)
        .boxDecoration(color: Color(0xFFF7F8F8), radius: 10)
    }

    private func holdLegDate(_ raw: String) -> String {
        guard let date = DateTime.tryParse(raw) else { return raw }
        return Formatters.shortDate(date)
    }

    /// SizedBox(width: 88) › FittedBox(scaleDown, centerRight).
    private func flightTime(_ value: String) -> some View {
        Text(value)
            .textStyle(AppTypography.body(11.5, weight: .w600, color: AppColors.textSecondary))
            .lineLimit(1)
            .minimumScaleFactor(0.1)
            .frame(width: 88, alignment: .trailing)
    }

    private func totalCard(_ total: Double, _ currency: String, _ passengers: Int) -> some View {
        card {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Total due")
                        .textStyle(AppTypography.body(13, weight: .w700, color: AppColors.textPrimary))
                    VGap(3)
                    Text("\(passengers) \(passengers == 1 ? "traveller" : "travellers")")
                        .textStyle(AppTypography.body(10.5, color: AppColors.textPrimary))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(Formatters.price(total, currency))
                    .textStyle(AppTypography.heading(18, color: AppColors.success))
            }
        }
    }

    /// `_card({child, border})`. A Flutter `Container` adds its border widths
    /// to its padding, so the uniform 1pt border pads 15 and the 3pt left
    /// accent pads 17 on the left.
    @ViewBuilder
    private func card<Content: View>(leftAccent: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        if leftAccent {
            // Border(left: BorderSide(color: 0xFFFFC107, width: 3)) on a 14pt
            // radius: Flutter paints the ring between the outer rounded rect
            // and the rect deflated by 3pt on the left — a crescent that
            // tapers into the corners.
            content()
                .padding(EdgeInsets(top: 14, leading: 17, bottom: 14, trailing: 14))
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 14).fill(Color(0xFFFFC107))
                        UnevenRoundedRectangle(
                            cornerRadii: RectangleCornerRadii(
                                topLeading: 11,
                                bottomLeading: 11,
                                bottomTrailing: 14,
                                topTrailing: 14
                            )
                        )
                        .fill(AppColors.surface)
                        .padding(.leading, 3)
                    }
                )
        } else {
            content()
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .boxDecoration(color: AppColors.surface, radius: 14, borderColor: AppColors.border)
        }
    }

    private var bottomActions: some View {
        Button(action: onContinueToPayment) {
            Text("Continue to payment")
                .textStyle(AppTypography.body(16, weight: .w600, color: Colors.white))
        }
        .buttonStyle(ElevatedButtonStyle(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets(top: 14, leading: 0, bottom: 14, trailing: 0)
        ))
        // SafeArea(top: false) inside the container: the button clears the
        // home indicator while the white panel runs to the screen edge.
        .padding(16, 10, 16, 16)
        .frame(maxWidth: .infinity)
        .background(
            Color.clear
                .boxDecoration(
                    color: AppColors.surface,
                    shadows: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: Offset(0, -3)
                        ),
                    ]
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
