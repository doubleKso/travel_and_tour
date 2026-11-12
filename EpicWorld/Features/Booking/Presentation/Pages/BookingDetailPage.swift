// Port of lib/features/booking/presentation/pages/booking_detail_page.dart
import SwiftUI
import UIKit

/// Passenger details for the selected flight: the MAI booking form (contact +
/// travellers → `holdFlight` → confirmation), or the reservation-only "Booking
/// Form" enquiry for every other airline.
///
/// The Dart page is a `ConsumerStatefulWidget` mixing Riverpod (auth, member,
/// NRC catalogue, use cases) and the flight-booking BLoC; both come from the
/// `AppContainer` here. Its `State` object lives in `BookingDetailScreenState`.
struct BookingDetailPage: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router
    @Environment(\.routeEntryID) private var routeEntryID

    @State private var state = BookingDetailScreenState()
    /// The `_DropdownField` popup currently shown (Flutter `showMenu`).
    @State private var openMenu: BookingDetailMenuRequest? = nil

    init() {}

    var body: some View {
        let booking = container.flightBookingBloc.state
        let memberToken = memberAccountToken

        ZStack {
            content(booking)
        }
        .coordinateSpace(.named(bookingDetailRootSpace))
        .overlay {
            if let openMenu {
                BookingDetailMenuOverlay(request: openMenu) { self.openMenu = nil }
            }
        }
        .environment(\.bookingDetailMenuPresenter, BookingDetailMenuPresenter { openMenu = $0 })
        .onAppear {
            // initState: hybrid in one line pair — the booking flow comes from
            // the BLoC, the signed-in user from Riverpod (both the container).
            state.initState(
                booking: container.flightBookingBloc.state,
                user: container.authNotifier.state.user,
                memberAccount: currentMemberAccount
            )
        }
        // ref.listenManual(memberAccountProvider, (_, next) => next.whenData(_prefillFromMemberAccount))
        .onChange(of: memberToken) { _, _ in
            let value = container.memberAccount.state
            guard !value.isLoading, value.error == nil else { return }
            state.prefillFromMemberAccount(value.valueOrNull.flatMap { $0 })
        }
    }

    // MARK: - Riverpod / route bridges

    /// `ref.read(memberAccountProvider).valueOrNull`.
    private var currentMemberAccount: MemberAccount? {
        container.memberAccount.state.valueOrNull.flatMap { $0 }
    }

    /// Changes whenever the member-account provider emits a new value, so
    /// `onChange` can replay Riverpod's `listenManual`.
    private var memberAccountToken: String {
        let value = container.memberAccount.state
        let account = value.valueOrNull.flatMap { $0 }
        return "\(value.isLoading)|\(value.error == nil)|\(account == nil)|"
            + "\(account?.name ?? "")|\(account?.email ?? "")|\(account?.phone ?? "")"
    }

    /// Flutter's `mounted`: this route is still on the navigator's stack.
    private var mounted: Bool {
        guard let routeEntryID else { return true }
        return router.entries.contains { $0.id == routeEntryID }
    }

    // MARK: - Flows

    /// Holds the selected MAI seats before showing the customer the reservation
    /// confirmation. Payment must use this one successful hold rather than
    /// submit another request later in the checkout flow.
    private func continueToConfirmation(_ booking: FlightBookingState) async {
        let state = self.state
        let request = state.maiHoldRequest(booking)
        // showGeneralDialog(barrierDismissible: false, barrierColor: white,
        // pageBuilder: _ReservationLoadingScreen) — drawn as a full-page
        // overlay so it is guaranteed to be up before the call returns.
        state.reserving = true

        let result = await container.holdFlightUseCase(request)
        guard mounted else { return }
        state.reserving = false

        switch result {
        case .failure(let failure):
            let message: String
            if failure.isNetwork {
                message = "No internet connection. Please try again."
            } else if !failure.message.isEmpty {
                message = failure.message
            } else {
                message = "Unable to reserve your seats."
            }
            showHoldError(message)
        case .success(let response):
            container.flightBookingBloc.add(
                .heldReservationConfirmed(request: request, response: response)
            )
            // A guest has no account for the server to file this under, so the
            // device keeps the reference/email pair — the only way back to a hold
            // that has not been paid for. Signed-in customers get the same row
            // from `GetMyBookings` and need nothing stored here.
            if !container.authNotifier.state.isAuthenticated {
                Task { await rememberGuestBooking(booking, request, response) }
            }
        }
    }

    private func validateAndContinue(_ booking: FlightBookingState) async {
        let state = self.state
        state.showMaiValidation = true
        for i in state.expanded.indices {
            state.expanded[i] = true
        }
        // await WidgetsBinding.instance.endOfFrame
        await Task.yield()
        guard mounted,
              state.validateMaiForm(booking, townships: { code in container.nrcTownshipList(code).state })
        else {
            return
        }
        await continueToConfirmation(booking)
    }

    /// Files a just-held booking in this device's guest history.
    ///
    /// Only what a history card and a later lookup need: the pair the backend
    /// matches on, plus a cached copy of the row so the card can be drawn before
    /// `listGuestBookings` has answered. Nothing here fails the checkout — the
    /// customer still has the reference in their confirmation email.
    private func rememberGuestBooking(
        _ booking: FlightBookingState,
        _ request: FlightHoldRequest,
        _ response: FlightHoldResponse
    ) async {
        let email = Dart.str(request.contact["email"])?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if response.reference.isEmpty || email.isEmpty { return }
        let limit = !response.ticketTimeLimitLocal.isEmpty
            ? response.ticketTimeLimitLocal
            : response.ticketTimeLimit
        await GuestBookingStore.save(
            GuestBookingRecord(
                reference: response.reference,
                email: email,
                route: "\(booking.fromLocation.code) → \(booking.toLocation.code)",
                service: "flight",
                travelDate: DateFormat("yyyy-MM-dd").format(booking.departDate),
                savedAt: DateTime.now(),
                ticketTimeLimit: DateTime.tryParse(limit)?.toLocal(),
                amount: response.total > 0 ? response.total : booking.totalPrice,
                currency: !response.currency.isEmpty
                    ? response.currency
                    : (booking.selectedOutbound?.currency ?? "MMK"),
                status: GuestBookingStatus.pendingPayment,
                pnr: response.pnr
            )
        )
    }

    /// Abandons the checkout from the reservation confirmation.
    ///
    /// The same exit the payment screen uses: the hold and the half-finished
    /// booking are cleared — along with the promotion and any started payment,
    /// which belonged to the reservation being abandoned — and the customer
    /// lands back on the Home tab.
    private func leaveCheckout() async {
        await AppliedPromoStore.clear()
        await PendingSmartPayPaymentStore.clear()
        guard mounted else { return }
        container.flightBookingBloc.add(.bookingReset)
        container.mainShellTab.value = 0
        router.replaceAll([.mainShell])
    }

    private func showHoldError(_ message: String) {
        SnackBarCenter.shared.show(message, backgroundColor: AppColors.error, floating: true)
    }

    /// Opens the calendar for a `dd/MM/yyyy` field.
    ///
    /// `firstDate` narrows the selectable range — the passport expiry field
    /// passes its six-month floor so an unacceptable date cannot be picked in
    /// the first place, with the validator catching typed input.
    private func pickDate(
        _ ctrl: BookingDetailScreenState.TextEditingController,
        firstDate: DateTime? = nil,
        lastDate: DateTime? = nil
    ) async {
        let lower = firstDate ?? DateTime(1920)
        let upper = lastDate ?? DateTime(2060)
        let now = DateTime.now()
        let initial = now.isBefore(lower) ? lower : (now.isAfter(upper) ? upper : now)
        let picked: DateTime? = await showDialog { dismiss in
            BookingDetailDatePicker(
                initialDate: initial,
                firstDate: lower,
                lastDate: upper,
                onCancel: { dismiss(nil) },
                onConfirm: { dismiss($0) }
            )
        }
        if let picked {
            ctrl.text = "\(BookingDetailHelpers.pad2(picked.day))/\(BookingDetailHelpers.pad2(picked.month))/\(picked.year)"
        }
    }

    private func submitBooking(_ booking: FlightBookingState) async {
        let state = self.state
        state.showReservationValidation = true
        if !state.validateReservationForm() {
            // The errors sit under their fields, which may be scrolled out of view.
            SnackBarCenter.shared.show("Please check the highlighted fields.", floating: true)
            return
        }
        let user = container.authNotifier.state.user
        let name = BookingDetailScreenState.trim(state.bkName.text)
        let localPhone = BookingDetailScreenState.trim(state.bkPhone.text)
        let travellers = Dart.parseInt(BookingDetailScreenState.trim(state.bkTravellers.text)) ?? 0
        let phone = state.internationalPhone(state.bkCountryCode, localPhone)
        state.submitting = true
        let enquiryFlight = [booking.selectedOutbound, booking.selectedInbound]
            .compactMap { $0 }
            .first { !FlightBookingState.isBookableOption($0) } ?? booking.selectedOutbound!
        let preferredDate = state.enquiryDate(enquiryFlight.departure)
        let carrier = enquiryFlight.carrierCode?.trimmingCharacters(in: .whitespacesAndNewlines)
        let flightLabel = enquiryFlight.flightNumber?
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? " \(enquiryFlight.flightNumber!)"
            : ""
        let carrierLabel = carrier?.isEmpty == false ? " \(carrier!)" : ""
        let request = ServiceEnquiryRequest(
            service: "flight",
            refId: enquiryFlight.id,
            refName: "\(enquiryFlight.operatorName)\(carrierLabel)\(flightLabel) "
                + "· \(enquiryFlight.originCode) → \(enquiryFlight.destinationCode) "
                + "· \(Formatters.time(enquiryFlight.departure))",
            name: name,
            email: BookingDetailScreenState.trim(state.bkEmail.text),
            phone: phone,
            preferredDate: preferredDate,
            pax: travellers,
            message: BookingDetailScreenState.trim(state.bkMessage.text),
            userId: user?.id ?? ""
        )
        let result = await container.createServiceEnquiryUseCase(request)
        guard mounted else { return }
        switch result {
        case .failure(let failure):
            state.submitting = false
            if failure.isNetwork {
                SnackBarCenter.shared.show("No internet connection.", floating: true)
            } else {
                SnackBarCenter.shared.show(
                    !failure.message.isEmpty ? failure.message : "Unable to submit booking.",
                    backgroundColor: AppColors.error,
                    floating: true
                )
            }
        case .success(let response):
            Task {
                await completeServiceEnquiry(
                    booking: booking,
                    enquiryFlight: enquiryFlight,
                    enquiryId: response.id,
                    name: name,
                    phone: phone,
                    travellers: travellers
                )
            }
        }
    }

    private func completeServiceEnquiry(
        booking: FlightBookingState,
        enquiryFlight: TripOptionModel,
        enquiryId: String,
        name: String,
        phone: String,
        travellers: Int
    ) async {
        let state = self.state
        // Captured while this route is certainly mounted: the reset below runs
        // after `replaceAll` has started tearing it down.
        let bookingBloc = container.flightBookingBloc
        let bookingRef = !enquiryId.isEmpty ? enquiryId : UUID().uuidString.lowercased()
        let email = BookingDetailScreenState.trim(state.bkEmail.text)
        let message = BookingDetailScreenState.trim(state.bkMessage.text)
        container.ticketNotifier.addTicket(
            TicketModel(
                id: bookingRef,
                bookingReference: bookingRef,
                outbound: booking.selectedOutbound!,
                inbound: booking.selectedInbound,
                passengerName: name,
                seatCount: travellers,
                totalPaid: booking.totalPrice,
                currency: booking.selectedOutbound!.currency,
                issuedAt: DateTime.now(),
                qrPayload: "SERVICE_ENQUIRY|\(bookingRef)",
                isReservation: true,
                phone: phone,
                email: email.isEmpty ? nil : email,
                message: message.isEmpty ? nil : message
            )
        )
        bookingBloc.add(.bookingCompleted)

        let destination: EnquirySuccessDestination? = await showDialog(barrierDismissible: false) { dismiss in
            ServiceEnquirySuccessDialog(
                airline: enquiryFlight.operatorName,
                route: "\(enquiryFlight.originCode) → \(enquiryFlight.destinationCode)",
                onViewHistory: { dismiss(.history) },
                onBrowseFlights: { dismiss(.home) }
            )
        }
        guard mounted, let destination else { return }

        if destination == .history {
            // Use the actual history route so its initState refreshes both booking
            // history and dcExec:GetMyServiceEnquiries immediately.
            router.replaceAll([.mainShell, .history()])
        } else {
            container.mainShellTab.value = 0
            router.replaceAll([.mainShell])
        }
        bookingBloc.add(.bookingReset)
    }

    // MARK: - Build

    @ViewBuilder
    private func content(_ booking: FlightBookingState) -> some View {
        if !state.isInitialized || booking.selectedOutbound == nil {
            // Completion clears the selection as the app transitions back to the main
            // shell. The bloc can rebuild this route for one frame before AutoRoute
            // removes it, so avoid dereferencing a now-cleared itinerary.
            Scaffold(backgroundColor: AppColors.background) { EmptyView() }
                .popScope(canPop: true)
        } else if !booking.isBookableSelected {
            // Non-MAI airlines are reservation-only → a simple "Booking Form" instead
            // of the full passenger form + payment flow.
            reservationScreen(booking)
                .popScope(canPop: true)
        } else if booking.stage == .confirmation {
            // Confirm remains in the existing detail route. The progress tracker moves
            // from Detail to Confirm without pushing another page on the navigator.
            BookingConfirmationContent(
                booking: booking,
                onBack: { container.flightBookingBloc.add(.returnedFromConfirmation) },
                onLeave: { Task { await leaveCheckout() } },
                onContinueToPayment: {
                    container.flightBookingBloc.add(.continuedToPayment)
                    router.push(.payment)
                }
            )
        } else {
            maiForm(booking)
                // The loading overlay stands in for a non-dismissible dialog
                // route, so the back gesture is held while it is up.
                .popScope(canPop: !state.reserving)
        }
    }

    private func maiForm(_ booking: FlightBookingState) -> some View {
        let outbound = booking.selectedOutbound!
        let inbound = booking.selectedInbound
        return Scaffold(
            backgroundColor: AppColors.background,
            appBar: { EmptyView() },
            bottomNavigationBar: { bottomBar(booking) }
        ) {
            ZStack {
                VStack(spacing: 0) {
                    CheckoutStepHeader(
                        stage: booking.stage,
                        fromCode: booking.fromLocation.code,
                        toCode: booking.toLocation.code,
                        subtitle: "\(Formatters.shortDate(booking.departDate))  ·  "
                            + "\(booking.totalTravellers) "
                            + (booking.totalTravellers == 1 ? "Traveller" : "Travellers")
                    )
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            contactSection()
                            VGap(20)
                            travellerSection(booking)
                            VGap(20)
                            // Trip summary — the selected legs on a pin timeline,
                            // placed under the traveller details.
                            TripSummaryCard(outbound: outbound, inbound: inbound)
                            VGap(20)
                        }
                        .padding(AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.screenH)
                        .background(KeyboardDismissArea())
                    }
                    .frame(maxHeight: .infinity)
                }
                // Dark scrim over the page content when the breakdown is open.
                // bottomNavigationBar sits outside the Scaffold body so it is
                // never dimmed — only the header + form area gets covered.
                if state.showBreakdown {
                    Colors.black.withValues(alpha: 0.45)
                        .ignoresSafeArea(edges: .top)
                        .contentShape(Rectangle())
                        .onTapGesture { state.showBreakdown = false }
                }
            }
            .background(KeyboardDismissArea())
        }
        .overlay {
            ZStack {
                if state.reserving {
                    ReservationLoadingScreen()
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.2), value: state.reserving)
        }
    }

    // ── Contact information ───────────────────────────────────────────────────

    private func contactSection() -> some View {
        SectionCard(
            title: LocaleKeys.booking_contact_information.tr(),
            subtitle: "We'll send your e-ticket and travel updates here."
        ) {
            VStack(spacing: 0) {
                nameFields(
                    title: state.contactTitle,
                    onTitleChanged: { state.updateContactTitle($0) },
                    firstNameController: state.contactFirstName,
                    lastNameController: state.contactLastName,
                    firstNameHint: "John",
                    lastNameHint: "Doe"
                )
                VGap(18)
                LabeledField(label: LocaleKeys.booking_mobile_number.tr(), required: true) {
                    PhoneField(
                        text: state.contactPhone.binding,
                        countryCode: state.contactCountryCode,
                        onCountryCodeChanged: { state.contactCountryCode = $0 },
                        errorText: state.maiError(
                            state.phoneValidator(state.contactPhone.text, countryCode: state.contactCountryCode)
                        )
                    )
                }
                VGap(18)
                LabeledField(label: LocaleKeys.common_email.tr(), required: true) {
                    InputField(
                        text: state.contactEmail.binding,
                        hint: "name@gmail.com",
                        inputType: .emailAddress,
                        errorText: state.maiError(state.emailValidator(state.contactEmail.text))
                    )
                }
            }
        }
    }

    /// Keeps the short title beside the first name, then gives the last name the
    /// whole card width. This avoids squeezing three controls into one phone row
    /// and leaves substantially more room for long passenger names.
    private func nameFields(
        title: String,
        onTitleChanged: @escaping (String) -> Void,
        firstNameController: BookingDetailScreenState.TextEditingController,
        lastNameController: BookingDetailScreenState.TextEditingController,
        firstNameHint: String,
        lastNameHint: String
    ) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                LabeledField(label: "Title") {
                    DropdownField(
                        value: title,
                        items: ["Mr", "Mrs", "Ms", "Mstr"],
                        onChanged: onTitleChanged
                    )
                }
                .frame(width: 94)
                HGap(12)
                LabeledField(label: LocaleKeys.booking_first_name.tr(), required: true) {
                    InputField(
                        text: firstNameController.binding,
                        hint: firstNameHint,
                        errorText: state.maiError(state.requiredValue(firstNameController.text, label: "First name"))
                    )
                }
                .frame(maxWidth: .infinity)
            }
            VGap(16)
            LabeledField(label: LocaleKeys.booking_last_name.tr(), required: true) {
                InputField(
                    text: lastNameController.binding,
                    hint: lastNameHint,
                    errorText: state.maiError(state.requiredValue(lastNameController.text, label: "Last name"))
                )
            }
        }
    }

    // ── Traveller details ─────────────────────────────────────────────────────

    private func travellerSection(_ booking: FlightBookingState) -> some View {
        SectionCard(
            title: LocaleKeys.booking_traveller_details.tr(),
            subtitle: "Enter names exactly as they appear on your ID / passport."
        ) {
            VStack(spacing: 0) {
                // The per-traveller lists are sized from the traveller count in
                // initState; the bound keeps a later count change from indexing
                // past them (Dart would throw a RangeError in build).
                ForEach(0..<min(booking.totalTravellers, state.travFirst.count), id: \.self) { i in
                    traveller(i, booking)
                }
            }
        }
    }

    private func traveller(_ i: Int, _ booking: FlightBookingState) -> some View {
        let travIsMyanmar = state.travNationality[i] == "Myanmar"
        let isAdult = state.isAdultTraveller(booking, i)
        let passportRequired = booking.passportRequiredFor(travellerIsMyanmar: travIsMyanmar)
        let nrcRequired = booking.nrcRequiredFor(travellerIsMyanmar: travIsMyanmar, isAdult: isAdult)
        return VStack(alignment: .leading, spacing: 0) {
            if i > 0 { VGap(12) }
            // Collapsible header
            Button {
                state.expanded[i].toggle()
            } label: {
                HStack(spacing: 0) {
                    Text(state.travellerLabel(booking, i))
                        .textStyle(AppTypography.body(14, weight: .w700, color: AppColors.primaryDark))
                    Text(" *")
                        .textStyle(AppTypography.body(14, color: AppColors.error))
                    Spacer(minLength: 0)
                    Icon(
                        state.expanded[i] ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primary
                    )
                }
                .padding(horizontal: 12, vertical: 10)
                .boxDecoration(color: AppColors.primarySurface, radius: 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.ink(radius: 10))
            if state.expanded[i] {
                travellerForm(
                    i,
                    booking,
                    isAdult: isAdult,
                    passportRequired: passportRequired,
                    nrcRequired: nrcRequired
                )
            }
        }
    }

    private func travellerForm(
        _ i: Int,
        _ booking: FlightBookingState,
        isAdult: Bool,
        passportRequired: Bool,
        nrcRequired: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                VGap(16)
                // Same as contact toggle
                HStack(spacing: 0) {
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { state.sameAsContact[i] },
                            set: { state.toggleSameAsContact(i, $0) }
                        )
                    )
                    .labelsHidden()
                    .tint(AppColors.primary)
                    .scaleEffect(0.85)
                    HGap(6)
                    Text(LocaleKeys.booking_same_as_contact_person.tr())
                        .textStyle(AppTypography.body(12.5, color: AppColors.textSecondary))
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                VGap(16)
            }

            nameFields(
                title: state.travTitle[i],
                onTitleChanged: { state.travTitle[i] = $0 },
                firstNameController: state.travFirst[i],
                lastNameController: state.travLast[i],
                firstNameHint: "e.g. Steve",
                lastNameHint: "e.g. Luke"
            )
            VGap(16)

            // Date of birth — full width, right after the name.
            LabeledField(label: LocaleKeys.booking_date_of_birth.tr(), required: true) {
                DateField(
                    text: state.travDob[i].binding,
                    hint: "dd/mm/yyyy",
                    onTap: {
                        Task {
                            await pickDate(
                                state.travDob[i],
                                lastDate: isAdult
                                    ? TravellerAgeRules.latestAdultDateOfBirth(booking.departDate)
                                    : booking.departDate
                            )
                        }
                    },
                    editable: true,
                    errorText: state.maiError(
                        state.travellerDateOfBirthValidator(booking, i, state.travDob[i].text)
                    )
                )
            }
            VGap(16)

            // Gender + Nationality — two dropdowns side by side.
            HStack(alignment: .top, spacing: 0) {
                LabeledField(label: LocaleKeys.booking_gender.tr(), required: true) {
                    DropdownField(
                        value: state.travGender[i],
                        items: ["Male", "Female"],
                        onChanged: { state.travGender[i] = $0 }
                    )
                }
                .frame(maxWidth: .infinity)
                HGap(12)
                LabeledField(label: LocaleKeys.booking_nationality.tr(), required: true) {
                    DropdownField(
                        value: state.travNationality[i],
                        items: ["Myanmar", "Thailand", "Singapore", "Malaysia", "Other"],
                        onChanged: { state.travNationality[i] = $0 }
                    )
                }
                .frame(maxWidth: .infinity)
            }
            VGap(16)

            documentFields(i, nrcRequired: nrcRequired, passportRequired: passportRequired)

            LabeledField(label: LocaleKeys.booking_remark.tr()) {
                InputField(
                    text: state.travRemark[i].binding,
                    hint: "Special meal, wheelchair, seat preference..."
                )
            }
        }
    }

    @ViewBuilder
    private func documentFields(_ i: Int, nrcRequired: Bool, passportRequired: Bool) -> some View {
        if nrcRequired {
            nrcField(i)
            VGap(16)
        }

        if passportRequired {
            HStack(alignment: .top, spacing: 0) {
                LabeledField(label: LocaleKeys.common_passport.tr(), required: true) {
                    InputField(
                        text: state.travPassport[i].binding,
                        hint: "MA1234567",
                        errorText: state.maiError(state.requiredValue(state.travPassport[i].text))
                    )
                }
                .frame(maxWidth: .infinity)
                HGap(12)
                LabeledField(label: LocaleKeys.booking_issued_country.tr(), required: true) {
                    DropdownField(
                        value: state.travIssuedCountry[i],
                        items: ["Myanmar", "Thailand", "Singapore", "Malaysia", "Other"],
                        onChanged: { state.travIssuedCountry[i] = $0 }
                    )
                }
                .frame(maxWidth: .infinity)
            }
            VGap(16)
            LabeledField(label: LocaleKeys.booking_passport_expiration_date.tr(), required: true) {
                DateField(
                    text: state.travExpiry[i].binding,
                    hint: "dd/mm/yyyy",
                    onTap: {
                        Task {
                            await pickDate(
                                state.travExpiry[i],
                                firstDate: BookingDetailScreenState.passportExpiryFloor()
                            )
                        }
                    },
                    errorText: state.maiError(state.passportExpiryValidator(state.travExpiry[i].text))
                )
            }
            VGap(16)
        }
    }

    private func nrcField(_ index: Int) -> some View {
        let codes = container.nrcCodeList.state
        let selectedCode = state.travNrcCode[index]
        let townships: AsyncValue<[NrcTownship]> = selectedCode.map { container.nrcTownshipList($0.code).state }
            ?? AsyncValue<[NrcTownship]>.data([])
        let errorText = state.nrcFieldError(index, townships: townships)

        return VStack(alignment: .leading, spacing: 0) {
            (
                Text(LocaleKeys.booking_nrc.tr())
                    .styled(AppTypography.body(12.5, weight: .w500, color: AppColors.textSecondary))
                + Text(" *")
                    .styled(AppTypography.body(12.5, weight: .w700, color: AppColors.error))
            )
            VGap(6)
            // One joined NRC field keeps all four parts visible on a phone:
            // `1 / KHALAPHA (N) 186608`. Township search moves into its own sheet
            // rather than competing with the six-digit number for vertical space.
            VStack(alignment: .leading, spacing: 0) {
                NrcCompactInput(
                    codes: codes,
                    selectedCode: selectedCode,
                    townships: townships,
                    selectedTownship: state.travNrcTownship[index],
                    type: state.travNrcType[index],
                    numberText: state.travNrc[index].binding,
                    hasSelectionError: errorText != nil,
                    onCodeChanged: { code in state.changeNrcCode(index, code) },
                    onTownshipSelected: { township in state.selectNrcTownship(index, township) },
                    onTypeChanged: { value in state.travNrcType[index] = value },
                    onNumberChanged: { _ in state.nrcNumberChanged(index) }
                )
                if let errorText {
                    Text(errorText)
                        .textStyle(AppTypography.body(11.5, color: AppColors.error))
                        .padding(.leading, 12)
                        .padding(.top, 5)
                }
            }
        }
    }

    // ── Reservation "Booking Form" screen (non-MAI airlines) ──────────────────

    private func reservationScreen(_ booking: FlightBookingState) -> some View {
        // On a mixed round-trip, name the non-MAI leg that caused this reservation
        // flow (rather than always showing the MAI outbound airline).
        let reservationLeg = [booking.selectedOutbound, booking.selectedInbound]
            .compactMap { $0 }
            .first { !FlightBookingState.isBookableOption($0) } ?? booking.selectedOutbound!
        let airline = reservationLeg.operatorName
        return Scaffold(
            backgroundColor: AppColors.background,
            appBar: { EmptyView() },
            bottomNavigationBar: { submitBar(booking) }
        ) {
            VStack(spacing: 0) {
                // Green header WITHOUT the step tracker.
                CheckoutStepHeader(
                    stage: booking.stage,
                    fromCode: booking.fromLocation.code,
                    toCode: booking.toLocation.code,
                    subtitle: "\(Formatters.shortDate(booking.departDate))  ·  \(airline)",
                    showTracker: false
                )
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Alert card explaining the booking process.
                        BookingProcessAlert(airline: airline)
                        VGap(20)
                        SectionCard(
                            title: LocaleKeys.booking_booking_form.tr(),
                            subtitle: "Send your details — we'll hold your seat and confirm "
                                + "by phone. Pay at our office.",
                            subtitleSize: 10.5
                        ) {
                            // Errors show under each field once a submit has been
                            // tried, then update as the customer corrects them.
                            reservationFields
                        }
                        VGap(20)
                    }
                    .padding(AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.screenH)
                    .background(KeyboardDismissArea())
                }
                .frame(maxHeight: .infinity)
            }
            .background(KeyboardDismissArea())
        }
    }

    private var reservationFields: some View {
        VStack(spacing: 0) {
            reservationContactFields
            VGap(18)
            reservationTripFields
        }
    }

    private var reservationContactFields: some View {
        VStack(spacing: 0) {
            LabeledField(label: LocaleKeys.common_full_name.tr(), required: true) {
                InputField(
                    text: state.bkName.binding,
                    hint: "e.g. John Doe",
                    errorText: state.reservationError(state.requiredValue(state.bkName.text, label: "Full name"))
                )
            }
            VGap(18)
            LabeledField(label: LocaleKeys.booking_mobile_number.tr(), required: true) {
                PhoneField(
                    text: state.bkPhone.binding,
                    countryCode: state.bkCountryCode,
                    onCountryCodeChanged: { state.bkCountryCode = $0 },
                    errorText: state.reservationError(
                        state.phoneValidator(state.bkPhone.text, countryCode: state.bkCountryCode)
                    )
                )
            }
            VGap(18)
            LabeledField(label: LocaleKeys.common_email.tr(), required: true) {
                InputField(
                    text: state.bkEmail.binding,
                    hint: "name@email.com",
                    inputType: .emailAddress,
                    errorText: state.bkEmailFieldError()
                )
            }
        }
    }

    private var reservationTripFields: some View {
        VStack(spacing: 0) {
            LabeledField(label: LocaleKeys.booking_travellers.tr(), required: true) {
                InputField(
                    text: state.bkTravellers.binding,
                    hint: "1",
                    inputType: .numberPad,
                    inputFormatter: BookingDetailHelpers.digitsOnly,
                    errorText: state.reservationError(state.travellersValidator(state.bkTravellers.text))
                )
            }
            VGap(18)
            LabeledField(label: LocaleKeys.booking_preferred_travel_date.tr()) {
                DateField(
                    text: state.bkDate.binding,
                    hint: "dd/mm/yyyy",
                    onTap: { Task { await pickDate(state.bkDate) } },
                    editable: true
                )
            }
            VGap(18)
            // Message — a taller box than the other fields.
            LabeledField(label: LocaleKeys.common_message.tr()) {
                InputField(
                    text: state.bkMessage.binding,
                    hint: "Anything we should know? (optional)",
                    inputType: .default,
                    minLines: 4,
                    maxLines: 6
                )
            }
        }
    }

    private func submitBar(_ booking: FlightBookingState) -> some View {
        Button {
            Task { await submitBooking(booking) }
        } label: {
            Text(LocaleKeys.booking_submit_booking.tr())
                .textStyle(AppTypography.body(16, weight: .w700, color: Colors.white))
        }
        .buttonStyle(ElevatedButtonStyle(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            cornerRadius: 14,
            padding: EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0)
        ))
        .disabled(state.submitting)
        // SafeArea(top: false) › Padding(16, 12, 16, 12)
        .padding(16, 12, 16, 12)
        .frame(maxWidth: .infinity)
        .background(
            Color.clear
                .boxDecoration(
                    color: AppColors.surface,
                    shadows: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 16,
                            offset: Offset(0, -4)
                        ),
                    ]
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // ── Bottom CTA ────────────────────────────────────────────────────────────

    private func bottomBar(_ booking: FlightBookingState) -> some View {
        let total = booking.totalPrice
        let bottomInset = BookingDetailHelpers.safeAreaInsets.bottom

        // Container carries the card look and reaches the very bottom edge of the
        // screen (no gap). SafeArea lives *inside* so only the content clears the
        // home indicator — the white fill + shadow still run flush to the bottom.
        return VStack(spacing: 0) {
            // Expanded breakdown grows UPWARD, above the fixed summary row —
            // the Amount Detail line + price + Pay button never move.
            // AnimatedSize(220ms, easeOutCubic, alignment: bottomCenter).
            amountBreakdown(booking, total)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: state.showBreakdown ? nil : 0, alignment: .bottom)
                .clipped()
                .accessibilityHidden(!state.showBreakdown)
            // Fixed summary row: "Amount Detail" + inline dropdown + price.
            HStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text(LocaleKeys.booking_amount_detail.tr())
                        .textStyle(AppTypography.body(13, weight: .w600, color: AppColors.textSecondary))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    HGap(4)
                    Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.primary)
                        .rotationEffect(.degrees(state.showBreakdown ? 180 : 0))
                        .animation(.linear(duration: 0.2), value: state.showBreakdown)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HGap(8)
                Text(Formatters.price(total))
                    .textStyle(AppTypography.heading(18, color: AppColors.primary))
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture { state.showBreakdown.toggle() }
            VGap(10)
            // Continue button.
            Button {
                Task { await validateAndContinue(booking) }
            } label: {
                Text(LocaleKeys.booking_continue.tr())
                    .textStyle(AppTypography.body(16, weight: .w700, color: Colors.white))
            }
            .buttonStyle(ElevatedButtonStyle(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                cornerRadius: 14,
                padding: EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0)
            ))
        }
        .animation(.timingCurve(0.215, 0.61, 0.355, 1, duration: 0.22), value: state.showBreakdown)
        .padding(16, 10, 16, bottomInset > 0 ? bottomInset - 8 : 2)
        .frame(maxWidth: .infinity)
        .boxDecoration(
            color: AppColors.surface,
            shadows: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: Offset(0, -4)
                ),
            ]
        )
        .ignoresSafeArea(.container, edges: .bottom)
    }

    /// Itemised fare panel shown above the Amount Detail row when expanded.
    ///
    /// The grand total is the persistent Amount Detail row, so this panel shows
    /// only the itemisation (no repeated total): the fare, taxes and fees are
    /// decomposed from the grand total so they always add back up to it.
    private func amountBreakdown(_ booking: FlightBookingState, _ total: Double) -> some View {
        let subTotal = Int(total.rounded())
        let adults = booking.travellerCount

        return VStack(alignment: .leading, spacing: 0) {
            // Label sits OUTSIDE (above) the background panel.
            Text(LocaleKeys.booking_amount_summary.tr())
                .textStyle(AppTypography.body(15, weight: .w700, color: AppColors.accent))
                .padding(.leading, 2)
                .padding(.top, 10)
                .padding(.bottom, 10)
            VStack(alignment: .leading, spacing: 0) {
                VGap(0)
                AmountRow(
                    label: LocaleKeys.booking_adult_s.tr(args: ["\(adults)"]),
                    value: Formatters.price(Double(subTotal))
                )
                VGap(14)
                AmountRow(
                    label: LocaleKeys.booking_sub_total.tr(),
                    value: Formatters.price(Double(subTotal))
                )
                VGap(14)
                AmountRow(
                    label: LocaleKeys.booking_discount.tr(),
                    value: Formatters.price(0),
                    sign: "−"
                )
                DottedLineView()
                    .padding(.vertical, 14)
                HStack(spacing: 0) {
                    Text(LocaleKeys.common_grand_total.tr())
                        .textStyle(AppTypography.body(14, weight: .w700, color: AppColors.textPrimary))
                    Spacer(minLength: 0)
                    Text(Formatters.price(total))
                        .textStyle(AppTypography.body(14, weight: .w700, color: AppColors.textPrimary))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .boxDecoration(color: AppColors.background, radius: 14)
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - State

/// `_BookingDetailScreenState`: every field, controller and helper of the Dart
/// page's `State`, so the page logic (prefill, contact sync, document rules,
/// validators, the `holdFlight` request) can be unit-tested without a view.
/// Members keep their Dart names without the leading underscore; they are
/// internal rather than private so the tests can reach them.
@MainActor
@Observable
final class BookingDetailScreenState {
    /// Flutter's `TextEditingController`: observable text plus listeners that
    /// fire whenever the text changes, programmatically or from typing.
    @MainActor
    @Observable
    final class TextEditingController {
        private var value: String
        @ObservationIgnored private var listeners: [(token: Int, callback: () -> Void)] = []
        @ObservationIgnored private var nextToken = 0

        init(text: String = "") {
            value = text
        }

        var text: String {
            get { value }
            set {
                guard newValue != value else { return }
                value = newValue
                for listener in listeners {
                    listener.callback()
                }
            }
        }

        /// `addListener`; returns a token for `removeListener`.
        @discardableResult
        func addListener(_ callback: @escaping () -> Void) -> Int {
            nextToken += 1
            listeners.append((token: nextToken, callback: callback))
            return nextToken
        }

        func removeListener(_ token: Int) {
            listeners.removeAll { $0.token == token }
        }

        /// The SwiftUI side of `TextFormField(controller:)`.
        var binding: Binding<String> {
            Binding(get: { self.text }, set: { self.text = $0 })
        }
    }

    var showMaiValidation = false

    // ── Contact info ──────────────────────────────────────────────────────────
    let contactFirstName = TextEditingController()
    let contactLastName = TextEditingController()
    let contactPhone = TextEditingController()
    let contactEmail = TextEditingController()
    var contactTitle = "Mr"
    var contactCountryCode = "+95"

    // ── Traveller per-item state ──────────────────────────────────────────────
    var expanded: [Bool] = []
    var sameAsContact: [Bool] = []
    var travFirst: [TextEditingController] = []
    var travLast: [TextEditingController] = []
    var travTitle: [String] = []
    var travGender: [String] = []
    var travDob: [TextEditingController] = []
    var travNationality: [String] = []
    var travNrc: [TextEditingController] = []
    var travNrcCode: [NrcCode?] = []
    var travNrcTownship: [NrcTownship?] = []
    var travNrcType: [String] = []
    var travPassport: [TextEditingController] = []
    var travIssuedCountry: [String] = []
    var travExpiry: [TextEditingController] = []
    var travRemark: [TextEditingController] = []
    var showBreakdown = false

    // ── Reservation "Booking Form" (non-MAI airlines) ─────────────────────────
    var showReservationValidation = false
    let bkName = TextEditingController()
    let bkPhone = TextEditingController()
    let bkEmail = TextEditingController()
    let bkDate = TextEditingController()
    let bkTravellers = TextEditingController()
    let bkMessage = TextEditingController()
    var bkCountryCode = "+95"
    var submitting = false

    // ── Swift-only stand-ins for Flutter widget state ─────────────────────────
    /// The NRC `FormField`'s own "has the user interacted" flag
    /// (`autovalidateMode: onUserInteraction`). Its `ValueKey` includes the
    /// selected code and township, so changing either resets the flag.
    var nrcFieldInteracted: [Bool] = []
    /// The Booking Form email field validates on interaction by itself
    /// (`autovalidateMode: AutovalidateMode.onUserInteraction`).
    var bkEmailInteracted = false
    /// The non-dismissible "Reserving your seats..." screen is up.
    var reserving = false
    private(set) var isInitialized = false

    init() {}

    // MARK: initState

    func initState(booking: FlightBookingState, user: AuthUser?, memberAccount: MemberAccount?) {
        guard !isInitialized else { return }
        isInitialized = true
        let n = booking.totalTravellers
        // Pre-fill the reservation form's preferred date with the searched date.
        bkDate.text = DateFormat("dd/MM/yyyy").format(booking.departDate)
        bkTravellers.text = String(booking.totalTravellers)
        prefillFromAuthUser(user)
        expanded = Array(repeating: true, count: n)
        sameAsContact = Array(repeating: false, count: n)
        travFirst = (0..<n).map { _ in TextEditingController() }
        travLast = (0..<n).map { _ in TextEditingController() }
        travTitle = Array(repeating: "Mr", count: n)
        travGender = Array(repeating: "Male", count: n)
        travDob = (0..<n).map { _ in TextEditingController() }
        // Seed each traveller's nationality from the home Nationality dropdown so
        // document requirements start out consistent with the search.
        travNationality = Array(repeating: booking.isForeigner ? "Other" : "Myanmar", count: n)
        travNrc = (0..<n).map { _ in TextEditingController() }
        // Every new traveller starts at NRC code 1. Once the code catalogue has
        // loaded, the picker replaces this seed object with its full API record.
        travNrcCode = [NrcCode?](repeating: NrcCode(code: "1", nameEn: "", nameMm: ""), count: n)
        travNrcTownship = [NrcTownship?](repeating: nil, count: n)
        travNrcType = Array(repeating: "N", count: n)
        travPassport = (0..<n).map { _ in TextEditingController() }
        travIssuedCountry = Array(repeating: "Myanmar", count: n)
        travExpiry = (0..<n).map { _ in TextEditingController() }
        travRemark = (0..<n).map { _ in TextEditingController() }
        nrcFieldInteracted = Array(repeating: false, count: n)
        contactFirstName.addListener { [weak self] in self?.syncSameAsContactNames() }
        contactLastName.addListener { [weak self] in self?.syncSameAsContactNames() }
        // A Member-tab visit may have already loaded GetMe. Use that cached
        // profile at once, then keep listening for an in-flight first response.
        prefillFromMemberAccount(memberAccount)
        // From here on a change to the email controller is an interaction
        // with the field (TextFormField turns controller changes into didChange).
        bkEmail.addListener { [weak self] in self?.bkEmailInteracted = true }
    }

    // MARK: Helpers

    /// Seed the form from the session immediately, then let `GetMe` complete
    /// optional profile fields such as a phone number. Existing form values are
    /// never replaced: the traveller remains in control after editing a field.
    func prefillFromAuthUser(_ user: AuthUser?) {
        guard let user else { return }
        let name = !Self.trim(user.displayName).isEmpty ? user.displayName : user.username
        prefillContactDetails(name: name, email: user.email, phone: user.phone)
    }

    func prefillFromMemberAccount(_ account: MemberAccount?) {
        guard let account else { return }
        prefillContactDetails(name: account.name, email: account.email, phone: account.phone)
    }

    func prefillContactDetails(name: String, email: String, phone: String) {
        let normalizedName = Self.trim(name)
        if !normalizedName.isEmpty {
            fillContactName(normalizedName)
            if Self.trim(bkName.text).isEmpty { bkName.text = normalizedName }
        }
        let normalizedEmail = Self.trim(email)
        if !normalizedEmail.isEmpty {
            if Self.trim(contactEmail.text).isEmpty {
                contactEmail.text = normalizedEmail
            }
            if Self.trim(bkEmail.text).isEmpty { bkEmail.text = normalizedEmail }
        }

        // The Dart `setState(() {})` after a country-code change is implicit:
        // the codes are observed.
        let normalizedPhone = Self.trim(phone)
        if !normalizedPhone.isEmpty {
            if Self.trim(contactPhone.text).isEmpty {
                let value = profilePhoneValue(normalizedPhone, fallbackCountryCode: contactCountryCode)
                if !value.localNumber.isEmpty {
                    contactPhone.text = value.localNumber
                    if value.countryCode != contactCountryCode {
                        contactCountryCode = value.countryCode
                    }
                }
            }
            if Self.trim(bkPhone.text).isEmpty {
                let value = profilePhoneValue(normalizedPhone, fallbackCountryCode: bkCountryCode)
                if !value.localNumber.isEmpty {
                    bkPhone.text = value.localNumber
                    if value.countryCode != bkCountryCode {
                        bkCountryCode = value.countryCode
                    }
                }
            }
        }
    }

    func fillContactName(_ fullName: String) {
        let parts = fullName
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        if parts.isEmpty { return }
        if Self.trim(contactFirstName.text).isEmpty {
            contactFirstName.text = parts[0]
        }
        if Self.trim(contactLastName.text).isEmpty && parts.count > 1 {
            contactLastName.text = parts.dropFirst().joined(separator: " ")
        }
    }

    func profilePhoneValue(
        _ phone: String,
        fallbackCountryCode: String
    ) -> (countryCode: String, localNumber: String) {
        let compact = phone.replacingOccurrences(of: #"[\s()\-]"#, with: "", options: .regularExpression)
        let digits = compact.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if digits.isEmpty || !compact.hasPrefix("+") {
            return (countryCode: fallbackCountryCode, localNumber: digits)
        }
        let countryCodes = phoneCountries.sorted { $0.dialCode.count > $1.dialCode.count }
        guard let country = countryCodes.first(where: { compact.hasPrefix($0.dialCode) }) else {
            return (countryCode: fallbackCountryCode, localNumber: digits)
        }
        return (
            countryCode: country.dialCode,
            localNumber: String(digits.dropFirst(country.dialCode.count - 1))
        )
    }

    func applySameAsContact(_ i: Int) {
        travTitle[i] = contactTitle
        travFirst[i].text = contactFirstName.text
        travLast[i].text = contactLastName.text
    }

    /// The "Same as Contact Person" switch's `onChanged`.
    func toggleSameAsContact(_ i: Int, _ v: Bool) {
        sameAsContact[i] = v
        if v { applySameAsContact(i) }
    }

    /// Keeps every linked traveller name live while "Same as Contact Person" is
    /// enabled. Controller updates repaint their text fields immediately.
    func syncSameAsContactNames() {
        for i in 0..<sameAsContact.count {
            if !sameAsContact[i] { continue }
            if travFirst[i].text != contactFirstName.text {
                travFirst[i].text = contactFirstName.text
            }
            if travLast[i].text != contactLastName.text {
                travLast[i].text = contactLastName.text
            }
        }
    }

    func updateContactTitle(_ title: String) {
        contactTitle = title
        for i in 0..<sameAsContact.count where sameAsContact[i] {
            travTitle[i] = title
        }
    }

    func isAdultTraveller(_ booking: FlightBookingState, _ index: Int) -> Bool {
        index < booking.travellerCount
    }

    func travellerType(_ booking: FlightBookingState, _ index: Int) -> String {
        if index < booking.travellerCount { return "Adult" }
        if index < booking.travellerCount + booking.childCount { return "Child" }
        return "Infant"
    }

    func travellerLabel(_ booking: FlightBookingState, _ index: Int) -> String {
        if index < booking.travellerCount { return "Adult \(index + 1)" }
        if index < booking.travellerCount + booking.childCount {
            return "Child \(index - booking.travellerCount + 1)"
        }
        return "Infant \(index - booking.travellerCount - booking.childCount + 1)"
    }

    func requiredValue(_ value: String?, label: String = "This field") -> String? {
        value == nil || Self.trim(value!).isEmpty ? "\(label) is required." : nil
    }

    /// Both instant-booking contacts and office enquiries use one of the
    /// supported mailbox domains. (`\w` is ASCII-only in Dart, so it is spelt
    /// out for ICU.)
    static let emailPattern = try! NSRegularExpression(
        pattern: #"^[A-Za-z0-9_.+\-]+@(email\.com|gmail\.com|systematic-business\.com)$"#,
        options: [.caseInsensitive]
    )

    func emailValidator(_ value: String?) -> String? {
        let text = Self.trim(value ?? "")
        if text.isEmpty { return "Email is required." }
        if !Self.hasMatch(Self.emailPattern, text) {
            return "Invalid email format! Use @gmail.com or @email.com."
        }
        return nil
    }

    /// A Myanmar (+95) number must be a mobile: 9 then 7–9 digits, with or
    /// without the leading 0. Other countries take 6–14 digits.
    static let myanmarMobilePattern = try! NSRegularExpression(pattern: #"^0?9[0-9]{7,9}$"#)

    func phoneValidator(_ value: String?, countryCode: String) -> String? {
        let digits = Self.digits(value ?? "")
        if digits.isEmpty { return "Mobile number is required." }
        let valid = countryCode == "+95"
            ? Self.hasMatch(Self.myanmarMobilePattern, digits)
            : digits.count >= 6 && digits.count <= 14
        return valid ? nil : "Enter a valid phone number."
    }

    func travellersValidator(_ value: String?) -> String? {
        let count = Dart.parseInt(Self.trim(value ?? "")) ?? 0
        if count < 1 { return "Enter the number of travellers." }
        if count > FlightBookingState.maxTravellers {
            return "Up to \(FlightBookingState.maxTravellers) travellers per booking."
        }
        return nil
    }

    func internationalPhone(_ countryCode: String, _ localNumber: String) -> String {
        let number = Self.digits(localNumber)
        if Self.trim(localNumber).hasPrefix("+") { return "+\(number)" }
        return "\(Self.trim(countryCode))\(number)"
    }

    func requiredDateValidator(_ value: String?) -> String? {
        let text = Self.trim(value ?? "")
        if text.isEmpty { return "This field is required." }
        do {
            _ = try DateFormat("dd/MM/yyyy").parseStrict(text)
            return nil
        } catch {
            return "Enter a valid date."
        }
    }

    func travellerDateOfBirthValidator(
        _ booking: FlightBookingState,
        _ travellerIndex: Int,
        _ value: String?
    ) -> String? {
        if let dateError = requiredDateValidator(value) { return dateError }

        guard let dateOfBirth = try? DateFormat("dd/MM/yyyy").parseStrict(Self.trim(value ?? "")) else {
            return nil
        }
        if isAdultTraveller(booking, travellerIndex)
            && !TravellerAgeRules.isOlderThan12(dateOfBirth: dateOfBirth, travelDate: booking.departDate) {
            return "Adult must be older than 12 years on the departure date."
        }
        return nil
    }

    /// Earliest passport expiry the airline will accept: six months out, counted
    /// from the first of the current month. Most carriers refuse to board a
    /// passport expiring inside six months of travel, so the form rejects it
    /// here rather than letting the booking fail at the counter.
    ///
    /// `now` defaults to the clock, as in Dart; tests pass a fixed day.
    static func passportExpiryFloor(_ now: DateTime = DateTime.now()) -> DateTime {
        DateTime(now.year, now.month + 6, 1)
    }

    func passportExpiryValidator(_ value: String?, now: DateTime = DateTime.now()) -> String? {
        if let required = requiredDateValidator(value) { return required }
        guard let parsed = try? DateFormat("dd/MM/yyyy").parseStrict(Self.trim(value ?? "")) else {
            return nil
        }
        let floor = Self.passportExpiryFloor(now)
        if parsed.isBefore(floor) {
            return "Passport must be valid until "
                + "\(DateFormat("MMMM yyyy").format(floor)) or later."
        }
        return nil
    }

    /// Formats the form's `dd/MM/yyyy` values to the ISO date expected by
    /// `holdFlight`. An unfilled or incomplete optional date remains empty.
    func holdDate(_ value: String) -> String {
        let input = Self.trim(value)
        if input.isEmpty { return "" }
        do {
            return DateFormat("yyyy-MM-dd").format(try DateFormat("dd/MM/yyyy").parseStrict(input))
        } catch {
            return ""
        }
    }

    /// Serializes the API-backed NRC fields in the standard form expected by
    /// `holdFlight`, e.g. `12/MaBaNa(N)123456`.
    func nrcValue(_ index: Int) -> String {
        let code = travNrcCode[index]?.code ?? ""
        let township = travNrcTownship[index]?.short ?? ""
        let number = Self.trim(travNrc[index].text)
        if code.isEmpty || township.isEmpty || number.isEmpty { return "" }
        return "\(code)/\(township)(\(travNrcType[index]))\(number)"
    }

    static let nrcNumberPattern = try! NSRegularExpression(pattern: #"^[0-9]{6}$"#)

    func nrcNumberValidator(_ value: String?) -> String? {
        let number = Self.trim(value ?? "")
        if number.isEmpty { return "NRC number is required." }
        if !Self.hasMatch(Self.nrcNumberPattern, number) {
            return "Enter the 6-digit NRC number."
        }
        return nil
    }

    /// The NRC `FormField`'s validator.
    func nrcSelectionValidator(_ index: Int, townships: AsyncValue<[NrcTownship]>) -> String? {
        let selectedCode = travNrcCode[index]
        if selectedCode == nil || selectedCode!.code.isEmpty {
            return "Select NRC code."
        }
        if townships.hasError { return "Unable to load townships." }
        if travNrcTownship[index] == nil { return "Select township." }
        return nrcNumberValidator(travNrc[index].text)
    }

    /// Captures the exact values typed in the Contact Information and Traveller
    /// Information form sections for the MAI `holdFlight` request.
    func maiHoldRequest(_ booking: FlightBookingState) -> FlightHoldRequest {
        let passengers: [JSON] = (0..<travFirst.count).map { i in
            let gender = travGender[i].lowercased()
            let remark = Self.trim(travRemark[i].text)
            let remarkValue: Any = remark.isEmpty ? NSNull() : remark
            let passenger: JSON = [
                "title": travTitle[i],
                "firstName": Self.trim(travFirst[i].text),
                "lastName": Self.trim(travLast[i].text),
                "type": travellerType(booking, i).lowercased(),
                "gender": gender,
                "dob": holdDate(travDob[i].text),
                "nationality": travNationality[i],
                "nrc": nrcValue(i),
                "passportNo": Self.trim(travPassport[i].text),
                "passportExpiry": holdDate(travExpiry[i].text),
                "issuedCountry": travIssuedCountry[i],
                "remark": remarkValue,
            ]
            return passenger
        }
        let firstName = Self.trim(contactFirstName.text)
        let lastName = Self.trim(contactLastName.text)
        let selected = [booking.selectedOutbound, booking.selectedInbound].compactMap { $0 }

        let contact: JSON = [
            "title": contactTitle,
            "firstName": firstName,
            "lastName": lastName,
            "fullName": [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " "),
            "email": Self.trim(contactEmail.text),
            "phone": Self.trim(contactPhone.text),
            "countryCode": contactCountryCode,
        ]
        return FlightHoldRequest(
            selections: selected.map { FlightHoldRequest.selectionFrom($0) },
            passengers: passengers,
            contact: contact,
            // Payment selection happens only after this call has succeeded and the
            // reservation confirmation is displayed.
            paymentMethod: nil,
            acceptPriceChange: false
        )
    }

    func enquiryDate(_ fallback: DateTime) -> String {
        do {
            return DateFormat("yyyy-MM-dd").format(
                try DateFormat("dd/MM/yyyy").parseStrict(Self.trim(bkDate.text))
            )
        } catch {
            return DateFormat("yyyy-MM-dd").format(fallback)
        }
    }

    // MARK: Form state (Flutter `Form` / `FormField` stand-ins)

    /// An MAI-form field's visible error: errors show once Continue has been
    /// tried (`AutovalidateMode.onUserInteraction` after `validate()`).
    func maiError(_ message: String?) -> String? {
        showMaiValidation ? message : nil
    }

    /// A Booking Form field's visible error, as `maiError`.
    func reservationError(_ message: String?) -> String? {
        showReservationValidation ? message : nil
    }

    /// The Booking Form email field also validates on its own as soon as it
    /// has been changed.
    func bkEmailFieldError() -> String? {
        showReservationValidation || bkEmailInteracted ? emailValidator(bkEmail.text) : nil
    }

    /// The NRC `FormField`'s visible error.
    func nrcFieldError(_ index: Int, townships: AsyncValue<[NrcTownship]>) -> String? {
        guard showMaiValidation || nrcFieldInteracted[index] else { return nil }
        return nrcSelectionValidator(index, townships: townships)
    }

    /// The NRC `FormField`'s `ValueKey`.
    private func nrcSelectionKey(_ index: Int) -> String {
        "nrc-selection-\(index)-\(travNrcCode[index]?.code ?? "null")-\(travNrcTownship[index]?.id ?? "")"
    }

    /// A key change rebuilds the `FormField` with fresh state.
    private func updatingNrcSelection(_ index: Int, _ change: () -> Void) {
        let before = nrcSelectionKey(index)
        change()
        if nrcSelectionKey(index) != before { nrcFieldInteracted[index] = false }
    }

    func changeNrcCode(_ index: Int, _ code: NrcCode?) {
        updatingNrcSelection(index) {
            travNrcCode[index] = code
            travNrcTownship[index] = nil
        }
    }

    func selectNrcTownship(_ index: Int, _ township: NrcTownship) {
        updatingNrcSelection(index) { travNrcTownship[index] = township }
    }

    /// `onNumberChanged: (_) => field.didChange(null)`.
    func nrcNumberChanged(_ index: Int) {
        nrcFieldInteracted[index] = true
    }

    /// `_maiBookingFormKey.currentState?.validate()`, with every traveller
    /// expanded: the fields in the tree are exactly the ones checked here.
    func validateMaiForm(
        _ booking: FlightBookingState,
        townships: (String) -> AsyncValue<[NrcTownship]>
    ) -> Bool {
        var errors: [String?] = [
            requiredValue(contactFirstName.text, label: "First name"),
            requiredValue(contactLastName.text, label: "Last name"),
            phoneValidator(contactPhone.text, countryCode: contactCountryCode),
            emailValidator(contactEmail.text),
        ]
        for i in 0..<min(booking.totalTravellers, travFirst.count) where expanded[i] {
            let travIsMyanmar = travNationality[i] == "Myanmar"
            let isAdult = isAdultTraveller(booking, i)
            errors.append(requiredValue(travFirst[i].text, label: "First name"))
            errors.append(requiredValue(travLast[i].text, label: "Last name"))
            errors.append(travellerDateOfBirthValidator(booking, i, travDob[i].text))
            if booking.nrcRequiredFor(travellerIsMyanmar: travIsMyanmar, isAdult: isAdult) {
                let codeTownships: AsyncValue<[NrcTownship]> = travNrcCode[i].map { townships($0.code) }
                    ?? AsyncValue<[NrcTownship]>.data([])
                errors.append(nrcSelectionValidator(i, townships: codeTownships))
            }
            if booking.passportRequiredFor(travellerIsMyanmar: travIsMyanmar) {
                errors.append(requiredValue(travPassport[i].text))
                errors.append(passportExpiryValidator(travExpiry[i].text))
            }
        }
        return errors.allSatisfy { $0 == nil }
    }

    /// `_reservationFormKey.currentState?.validate()`.
    func validateReservationForm() -> Bool {
        let errors: [String?] = [
            requiredValue(bkName.text, label: "Full name"),
            phoneValidator(bkPhone.text, countryCode: bkCountryCode),
            emailValidator(bkEmail.text),
            travellersValidator(bkTravellers.text),
        ]
        return errors.allSatisfy { $0 == nil }
    }

    // MARK: Dart string helpers

    /// Dart `String.trim()`.
    nonisolated static func trim(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `value.replaceAll(RegExp(r'[^0-9]'), '')`.
    nonisolated static func digits(_ value: String) -> String {
        value.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
    }

    /// Dart `RegExp.hasMatch`.
    nonisolated static func hasMatch(_ regex: NSRegularExpression, _ text: String) -> Bool {
        regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }
}

// MARK: - Page-local helpers

private enum EnquirySuccessDestination {
    case history, home
}

/// Named coordinate space of the page, for anchoring dropdown menus.
private let bookingDetailRootSpace = "bookingDetailRoot"

private enum BookingDetailHelpers {
    @MainActor
    static var keyWindow: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
    }

    /// `MediaQuery.of(context).padding`.
    @MainActor
    static var safeAreaInsets: UIEdgeInsets { keyWindow?.safeAreaInsets ?? .zero }

    /// `MediaQuery.of(context).size`.
    @MainActor
    static var screenSize: CGSize { keyWindow?.bounds.size ?? CGSize(width: 390, height: 844) }

    /// Content height of a scroll-controlled, `useSafeArea` sheet wrapped in
    /// `FractionallySizedBox(heightFactor:)`, excluding the bottom inset the
    /// sheet's own background already extends under.
    @MainActor
    static func sheetContentHeight(_ heightFactor: CGFloat) -> CGFloat {
        let insets = safeAreaInsets
        return max(0, (screenSize.height - insets.top) * heightFactor - insets.bottom)
    }

    /// `FocusManager.instance.primaryFocus?.unfocus()`.
    @MainActor
    static func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// `FilteringTextInputFormatter.digitsOnly`.
    static func digitsOnly(_ text: String) -> String {
        text.filter { $0.isASCII && $0.isNumber }
    }

    /// `n.toString().padLeft(2, '0')`.
    static func pad2(_ value: Int) -> String {
        value < 10 && value >= 0 ? "0\(value)" : String(value)
    }
}

/// Clears the active text-field focus and closes the software keyboard when
/// the traveller taps an unused part of either booking form.
private struct KeyboardDismissArea: View {
    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture { BookingDetailHelpers.dismissKeyboard() }
    }
}

/// Non-dismissible progress state while `holdFlight` reserves the selected
/// seats. It deliberately occupies the full page so the customer cannot alter
/// traveller data while the airline is processing the reservation.
private struct ReservationLoadingScreen: View {
    var body: some View {
        VStack(spacing: 0) {
            FlightOrbitLoader(size: 150)
            VGap(28)
            Text("Reserving your seats...")
                .textStyle(AppTypography.heading(20, color: AppColors.textPrimary))
            VGap(8)
            Text("Please don’t close this page.")
                .textStyle(AppTypography.body(14, color: AppColors.textSecondary))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.surface.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture {}
    }
}

/// A sparse dotted horizontal separator (wide gaps). Dart `_DottedLine`;
/// renamed so it cannot clash with the ticket shell's public `DottedLine`.
private struct DottedLineView: View {
    var body: some View {
        Canvas { context, size in
            let dash: CGFloat = 3.0
            let gap: CGFloat = 6.0
            let count = Int((size.width / (dash + gap)).rounded(.down))
            guard count > 0 else { return }
            // Row(mainAxisAlignment: spaceBetween) of `count` dashes.
            let step = count > 1 ? (size.width - dash) / CGFloat(count - 1) : 0
            for i in 0..<count {
                let rect = CGRect(x: CGFloat(i) * step, y: 0, width: dash, height: 1.5)
                context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(AppColors.border))
            }
        }
        .frame(height: 1.5)
    }
}

// ── Section card ──────────────────────────────────────────────────────────────

private struct SectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    var subtitleSize: CGFloat = 12
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).textStyle(AppTypography.heading(16))
            VGap(3)
            Text(subtitle)
                .textStyle(AppTypography.body(subtitleSize, color: AppColors.primary))
            VGap(16)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KeyboardDismissArea())
        .boxDecoration(
            color: AppColors.surface,
            radius: 18,
            shadows: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 20,
                    offset: Offset(0, 6)
                ),
            ]
        )
    }
}

// ── Labeled field wrapper ─────────────────────────────────────────────────────

private struct LabeledField<Child: View>: View {
    let label: String

    /// Adds a small red `*` after the label for mandatory fields.
    var required = false
    @ViewBuilder let child: () -> Child

    var body: some View {
        // Label floating on the top border — its white background notches the
        // outline, exactly like the home page fields.
        child()
            .padding(.top, 7)
            .overlay(alignment: .topLeading) {
                FloatLabel(label, required: required)
                    .padding(.horizontal, 4)
                    .background(AppColors.surface)
                    .padding(.leading, 12)
            }
    }
}

/// Field label — a touch more prominent than the home card's label, with an
/// optional red `*` marking a mandatory field.
private struct FloatLabel: View {
    let text: String
    let required: Bool

    init(_ text: String, required: Bool = false) {
        self.text = text
        self.required = required
    }

    var body: some View {
        let style = AppTypography.body(12.5, weight: .w500, color: AppColors.textSecondary)
        if !required {
            Text(text).textStyle(style)
        } else {
            Text("* ").styled(AppTypography.body(12.5, weight: .w700, color: AppColors.error))
                + Text(text).styled(style)
        }
    }
}

// ── Text input ────────────────────────────────────────────────────────────────

/// Field outline — matches the home search card (soft green-gray, radius 14).
private let fieldBorderColor = AppColors.border
// Matches the V2 home air-ticket search fields (the "From" box) so every input
// across the booking, contact and traveller cards shares the same corner.
private let fieldRadius: CGFloat = 4
private let formControlHeight: CGFloat = 48

/// The shared clean field decoration (`_fieldDecoration`): white fill, light
/// border, primary focus, red error outline with the message underneath, and
/// a 48pt minimum height so every control in a row lines up. A prefix icon
/// replaces the leading content padding and a suffix icon the trailing one,
/// as Material's `InputDecorator` does.
private struct BookingFormTextField: View {
    @Binding var text: String
    let hint: String
    let keyboardType: UIKeyboardType
    let minLines: Int
    let maxLines: Int
    let errorText: String?
    let readOnly: Bool
    let onTap: (() -> Void)?
    /// `inputFormatters`, applied to each edit.
    let formatter: ((String) -> String)?
    let onChanged: ((String) -> Void)?
    let contentPadding: EdgeInsets
    /// Where the error line starts (`contentPadding.left`).
    let errorLeading: CGFloat
    let prefix: AnyView?
    let suffix: AnyView?

    @FocusState private var focused: Bool

    private static let textStyle = AppTypography.body(13.5, weight: .w500)
    private static let hintStyle = AppTypography.body(13, color: AppColors.textPlaceholder)

    init(
        text: Binding<String>,
        hint: String,
        keyboardType: UIKeyboardType = .default,
        minLines: Int = 1,
        maxLines: Int = 1,
        errorText: String? = nil,
        readOnly: Bool = false,
        onTap: (() -> Void)? = nil,
        formatter: ((String) -> String)? = nil,
        onChanged: ((String) -> Void)? = nil,
        contentPadding: EdgeInsets = EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14),
        errorLeading: CGFloat = 14,
        prefix: AnyView? = nil,
        suffix: AnyView? = nil
    ) {
        _text = text
        self.hint = hint
        self.keyboardType = keyboardType
        self.minLines = minLines
        self.maxLines = maxLines
        self.errorText = errorText
        self.readOnly = readOnly
        self.onTap = onTap
        self.formatter = formatter
        self.onChanged = onChanged
        self.contentPadding = contentPadding
        self.errorLeading = errorLeading
        self.prefix = prefix
        self.suffix = suffix
    }

    var body: some View {
        let hasError = errorText != nil
        let borderColor: Color = hasError ? AppColors.error : (focused ? AppColors.primary : fieldBorderColor)
        let borderWidth: CGFloat = focused ? 1.4 : 1

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: maxLines > 1 ? .top : .center, spacing: 0) {
                if let prefix {
                    prefix
                }
                field
                    .padding(contentPadding)
                if let suffix {
                    suffix
                }
            }
            .frame(maxWidth: .infinity, minHeight: formControlHeight)
            .background(RoundedRectangle(cornerRadius: fieldRadius).fill(AppColors.surface))
            .overlay(RoundedRectangle(cornerRadius: fieldRadius).strokeBorder(borderColor, lineWidth: borderWidth))
            .contentShape(Rectangle())
            .onTapGesture {
                if readOnly {
                    onTap?()
                } else {
                    focused = true
                }
            }
            if let errorText {
                Text(errorText)
                    .textStyle(AppTypography.body(12, color: AppColors.error, letterSpacing: 0.4))
                    .padding(.top, 8)
                    .padding(.leading, errorLeading)
                    .padding(.trailing, 14)
            }
        }
    }

    @ViewBuilder
    private var field: some View {
        if readOnly {
            Text(text.isEmpty ? hint : text)
                .textStyle(text.isEmpty ? Self.hintStyle : Self.textStyle)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            TextField(
                "",
                text: $text,
                prompt: Text(hint).font(Self.hintStyle.font).foregroundColor(Self.hintStyle.color),
                axis: maxLines > 1 ? .vertical : .horizontal
            )
            .lineLimit(minLines...maxLines)
            .font(Self.textStyle.font)
            .foregroundStyle(Self.textStyle.color)
            .tint(AppColors.primary)
            .keyboardType(keyboardType)
            .textInputAutocapitalization(.never)
            .focused($focused)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: text) { _, newValue in
                if let formatter {
                    let formatted = formatter(newValue)
                    if formatted != newValue {
                        text = formatted
                        return
                    }
                }
                onChanged?(newValue)
            }
        }
    }
}

private struct InputField: View {
    @Binding var text: String
    let hint: String
    var inputType: UIKeyboardType = .default
    var minLines = 1
    var maxLines = 1
    var inputFormatter: ((String) -> String)? = nil
    /// The validator's message, when it is shown.
    var errorText: String? = nil

    var body: some View {
        BookingFormTextField(
            text: $text,
            hint: hint,
            keyboardType: inputType,
            minLines: minLines,
            maxLines: maxLines,
            errorText: errorText,
            formatter: inputFormatter
        )
    }
}

// ── Date field (tap to pick) ──────────────────────────────────────────────────

private struct DateField: View {
    @Binding var text: String
    let hint: String
    let onTap: () -> Void

    /// When true the user can type the date directly (dd/mm/yyyy, auto-slashed)
    /// AND still tap the calendar icon to pick it. When false the whole field is
    /// a tap-to-pick target (read-only).
    var editable = false
    var errorText: String? = nil

    var body: some View {
        let formatter: ((String) -> String)? = editable ? DateInputFormatter.format : nil
        BookingFormTextField(
            text: $text,
            hint: hint,
            keyboardType: editable ? .numberPad : .default,
            errorText: errorText,
            readOnly: !editable,
            onTap: editable ? nil : onTap,
            formatter: formatter,
            contentPadding: EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 0),
            suffix: AnyView(suffixIcon)
        )
    }

    /// Suffix icons sit in Material's 48pt suffix-icon box.
    @ViewBuilder
    private var suffixIcon: some View {
        if editable {
            Button(action: onTap) {
                Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textTertiary)
                    .frame(width: formControlHeight, height: formControlHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textTertiary)
                .frame(width: formControlHeight, height: formControlHeight)
        }
    }
}

/// Confirmation shown after an enquiry-only airline accepts the reservation.
private struct ServiceEnquirySuccessDialog: View {
    let airline: String
    let route: String
    let onViewHistory: () -> Void
    let onBrowseFlights: () -> Void

    var body: some View {
        // LayoutBuilder: the card is 560 wide at most, inside 18pt insets,
        // less its 26pt side padding.
        let available = min(560, BookingDetailHelpers.screenSize.width - 36) - 52
        let compact = available < 380

        VStack(spacing: 0) {
            Icon(Icons.check_rounded, size: 34, color: Color(0xFF009E68))
                .frame(width: 64, height: 64)
                .background(Circle().fill(Color(0xFFD5F8E7)))
            VGap(22)
            Text("Reservation received!")
                .textStyle(AppTypography.heading(23, weight: .w800))
                .multilineTextAlignment(.center)
            VGap(10)
            (
                Text("We've held your seat on ")
                    .styled(AppTypography.body(14, color: AppColors.textSecondary))
                + Text("\(airline) \(route)")
                    .styled(AppTypography.body(14, weight: .w700, color: AppColors.textSecondary))
                + Text(". Our team will call you shortly to confirm. Pay when you visit our office.")
                    .styled(AppTypography.body(14, color: AppColors.textSecondary))
            )
            .multilineTextAlignment(.center)
            VGap(24)
            if compact {
                VStack(spacing: 0) {
                    historyButton
                    VGap(10)
                    browseButton
                }
            } else {
                HStack(spacing: 0) {
                    historyButton
                    HGap(12)
                    browseButton
                }
            }
        }
        .padding(26, 40, 26, 30)
        .frame(maxWidth: 560)
        .boxDecoration(
            color: AppColors.surface,
            radius: 20,
            shadows: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: Offset(0, 10)
                ),
            ]
        )
        // Dialog(insetPadding: horizontal 18) — the modal host insets dialogs
        // by Material's default 40, so give 22 of it back.
        .padding(.horizontal, -22)
    }

    private var historyButton: some View {
        Button(action: onViewHistory) {
            Text("View in booking history")
                .textStyle(AppTypography.body(14, weight: .w700, color: Colors.white))
                .multilineTextAlignment(.center)
        }
        .buttonStyle(ElevatedButtonStyle(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumHeight: 50,
            cornerRadius: 12
        ))
        .frame(height: 50)
    }

    private var browseButton: some View {
        Button(action: onBrowseFlights) {
            Text("Browse more flights")
                .textStyle(AppTypography.body(14, weight: .w700, color: AppColors.primaryDark))
                .multilineTextAlignment(.center)
        }
        .buttonStyle(OutlinedButtonStyle(
            foregroundColor: AppColors.primaryDark,
            borderColor: AppColors.primary,
            minimumHeight: 50,
            cornerRadius: 12
        ))
        .frame(height: 50)
    }
}

/// Formats typed digits into `dd/mm/yyyy`, inserting the slashes automatically
/// and capping the input at 8 digits.
private enum DateInputFormatter {
    static func format(_ text: String) -> String {
        var digits = text.filter { $0.isASCII && $0.isNumber }
        if digits.count > 8 { digits = String(digits.prefix(8)) }
        var buf = ""
        for (i, character) in digits.enumerated() {
            if i == 2 || i == 4 { buf += "/" }
            buf.append(character)
        }
        return buf
    }
}

// ── Dropdown field ────────────────────────────────────────────────────────────

/// One open `_DropdownField` menu: the field's frame in the page, its options
/// and the current value.
private struct BookingDetailMenuRequest {
    let frame: CGRect
    let items: [String]
    let value: String
    let onSelected: (String) -> Void
}

private struct BookingDetailMenuPresenter {
    let present: (BookingDetailMenuRequest) -> Void
}

private struct BookingDetailMenuPresenterKey: EnvironmentKey {
    static let defaultValue: BookingDetailMenuPresenter? = nil
}

extension EnvironmentValues {
    fileprivate var bookingDetailMenuPresenter: BookingDetailMenuPresenter? {
        get { self[BookingDetailMenuPresenterKey.self] }
        set { self[BookingDetailMenuPresenterKey.self] = newValue }
    }
}

private struct DropdownField: View {
    let value: String
    let items: [String]
    let onChanged: (String) -> Void

    @Environment(\.bookingDetailMenuPresenter) private var presenter
    @State private var frame: CGRect = .zero

    /// Opens the option list anchored directly BELOW the field (instead of the
    /// default DropdownButton, which overlays the menu on top of the field).
    private func openMenu() {
        presenter?.present(BookingDetailMenuRequest(
            frame: frame,
            items: items,
            value: value,
            onSelected: onChanged
        ))
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(value)
                .textStyle(AppTypography.body(13.5, weight: .w500))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary)
        }
        // 14pt padding plus the 1pt border a Container adds to it.
        .padding(.horizontal, 15)
        .frame(height: formControlHeight)
        .frame(maxWidth: .infinity)
        .boxDecoration(color: AppColors.surface, radius: fieldRadius, borderColor: fieldBorderColor)
        .contentShape(Rectangle())
        .onTapGesture(perform: openMenu)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { frame = proxy.frame(in: .named(bookingDetailRootSpace)) }
                    .onChange(of: proxy.frame(in: .named(bookingDetailRootSpace))) { _, newFrame in
                        frame = newFrame
                    }
            }
        )
    }
}

/// Flutter `showMenu` as `_DropdownField` calls it: a field-wide white card
/// with a 1pt border and 4pt corners, 44pt items (the selected one bold,
/// primary-dark), placed 4pt under the field and kept 8pt inside the page.
/// A tap outside dismisses it.
private struct BookingDetailMenuOverlay: View {
    let request: BookingDetailMenuRequest
    let onDismiss: () -> Void

    @State private var appeared = false

    private static let itemHeight: CGFloat = 44
    private static let verticalPadding: CGFloat = 8
    private static let screenPadding: CGFloat = 8

    private var menuHeight: CGFloat {
        CGFloat(request.items.count) * Self.itemHeight + Self.verticalPadding * 2
    }

    private func origin(in size: CGSize) -> CGPoint {
        var x = request.frame.minX
        if x < Self.screenPadding {
            x = Self.screenPadding
        } else if x + request.frame.width > size.width - Self.screenPadding {
            x = size.width - Self.screenPadding - request.frame.width
        }
        var y = request.frame.maxY + 4
        if y < Self.screenPadding {
            y = Self.screenPadding
        } else if y + menuHeight > size.height - Self.screenPadding {
            y = size.height - Self.screenPadding - menuHeight
        }
        return CGPoint(x: x, y: y)
    }

    var body: some View {
        GeometryReader { geometry in
            let point = origin(in: geometry.size)
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onDismiss)
                menu
                    .frame(width: request.frame.width)
                    .scaleEffect(x: 1, y: appeared ? 1 : 0.6, anchor: .top)
                    .opacity(appeared ? 1 : 0)
                    .offset(x: point.x, y: point.y)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) { appeared = true }
        }
    }

    private var menu: some View {
        VStack(spacing: 0) {
            ForEach(request.items, id: \.self) { item in
                Button {
                    // Navigator.pop(context, value) — then onChanged(selected).
                    onDismiss()
                    request.onSelected(item)
                } label: {
                    Text(item)
                        .textStyle(AppTypography.body(
                            13.5,
                            weight: item == request.value ? .w700 : .w500,
                            color: item == request.value ? AppColors.primaryDark : AppColors.textPrimary
                        ))
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: Self.itemHeight, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.ink)
            }
        }
        .padding(.vertical, Self.verticalPadding)
        .background(RoundedRectangle(cornerRadius: fieldRadius).fill(AppColors.surface))
        .overlay(RoundedRectangle(cornerRadius: fieldRadius).strokeBorder(fieldBorderColor, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: fieldRadius))
        .shadow(color: Colors.black.withValues(alpha: 0.15), radius: 4, x: 0, y: 2)
    }
}

/// `showDatePicker` themed with `ColorScheme.light(primary: AppColors.primary)`:
/// Material's header, a calendar and Cancel / OK.
private struct BookingDetailDatePicker: View {
    let firstDate: DateTime
    let lastDate: DateTime
    let onCancel: () -> Void
    let onConfirm: (DateTime) -> Void

    @State private var selection: Date

    init(
        initialDate: DateTime,
        firstDate: DateTime,
        lastDate: DateTime,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping (DateTime) -> Void
    ) {
        self.firstDate = firstDate
        self.lastDate = lastDate
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        _selection = State(initialValue: initialDate.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Select date")
                .textStyle(AppTypography.labelLarge.copyWith(color: AppColors.textSecondary))
                .padding(24, 16, 12, 0)
            Text(DateFormat("EEE, MMM d").format(DateTime(date: selection)))
                .textStyle(AppTypography.headlineLarge.copyWith(weight: .w400))
                .padding(24, 28, 12, 12)
            MaterialDivider(height: 1, color: AppColors.divider)
            DatePicker(
                "",
                selection: $selection,
                in: firstDate.date...lastDate.date,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(AppColors.primary)
            .padding(.horizontal, 12)
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Button(action: onCancel) {
                    Text("Cancel").textStyle(AppTypography.labelLarge.copyWith(color: AppColors.primary))
                }
                .buttonStyle(TextButtonStyle())
                HGap(8)
                Button {
                    onConfirm(DateTime(date: selection))
                } label: {
                    Text("OK").textStyle(AppTypography.labelLarge.copyWith(color: AppColors.primary))
                }
                .buttonStyle(TextButtonStyle())
            }
            .padding(12, 0, 12, 12)
        }
        .frame(maxWidth: 360)
        .background(RoundedRectangle(cornerRadius: 28).fill(AppColors.surface))
    }
}

// ── NRC fields ──────────────────────────────────────────────────────────────

private struct NrcCompactInput: View {
    let codes: AsyncValue<[NrcCode]>
    let selectedCode: NrcCode?
    let townships: AsyncValue<[NrcTownship]>
    let selectedTownship: NrcTownship?
    let type: String
    @Binding var numberText: String
    let hasSelectionError: Bool
    let onCodeChanged: (NrcCode?) -> Void
    let onTownshipSelected: (NrcTownship) -> Void
    let onTypeChanged: (String) -> Void
    let onNumberChanged: (String) -> Void

    var body: some View {
        let borderWidth: CGFloat = hasSelectionError ? 1.25 : 1
        HStack(spacing: 0) {
            NrcCodePicker(codes: codes, value: selectedCode, onChanged: onCodeChanged)
                .padding(.leading, 9)
                .frame(width: 43)
            Text("/")
                .textStyle(AppTypography.body(14, weight: .w700, color: AppColors.textSecondary))
                .dynamicTypeSize(.large)
            HGap(5)
            NrcTownshipPicker(townships: townships, selected: selectedTownship, onSelected: onTownshipSelected)
                .frame(maxWidth: .infinity)
            NrcDivider()
            NrcTypePicker(value: type, onChanged: onTypeChanged)
                .frame(width: 50)
            NrcDivider()
            numberField
                .frame(width: 72)
        }
        // A Container insets its child by the border width.
        .padding(borderWidth)
        .frame(height: 48)
        .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(hasSelectionError ? AppColors.error : fieldBorderColor, lineWidth: borderWidth)
        )
    }

    /// `_nrcNumberDecoration()`: borderless, digits only, six at most.
    private var numberField: some View {
        TextField(
            "",
            text: $numberText,
            prompt: Text("123456")
                .font(AppTypography.body(12.5).font)
                .foregroundColor(AppColors.textPlaceholder)
        )
        .font(AppTypography.body(13, weight: .w600).font)
        .foregroundStyle(AppColors.textPrimary)
        .tint(AppColors.primary)
        .keyboardType(.numberPad)
        .padding(.horizontal, 6)
        .padding(.vertical, 14)
        .onChange(of: numberText) { _, newValue in
            let filtered = String(BookingDetailHelpers.digitsOnly(newValue).prefix(6))
            if filtered != newValue {
                numberText = filtered
                return
            }
            onNumberChanged(newValue)
        }
    }
}

private struct NrcDivider: View {
    var body: some View {
        // VerticalDivider(width: 1, thickness: 1, indent: 10, endIndent: 10)
        Rectangle()
            .fill(AppColors.dividerLight)
            .frame(width: 1)
            .padding(.vertical, 10)
            .frame(maxHeight: .infinity)
    }
}

private struct NrcCodePicker: View {
    let codes: AsyncValue<[NrcCode]>
    let value: NrcCode?
    let onChanged: (NrcCode?) -> Void

    var body: some View {
        let items = codes.valueOrNull ?? []
        let enabled = codes.hasValue && !items.isEmpty
        // The selected item and the hint read the same: the code, or `1`.
        let display = value?.code.isEmpty == false ? value!.code : "1"
        Menu {
            ForEach(Array(items.enumerated()), id: \.offset) { _, code in
                Button(code.code) { onChanged(code) }
            }
        } label: {
            HStack(spacing: 0) {
                Text(display)
                    .textStyle(AppTypography.body(13, weight: .w600))
                    .dynamicTypeSize(.large)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if codes.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(AppColors.primary)
                        .frame(width: 13, height: 13)
                } else {
                    Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textSecondary)
                }
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .disabled(!enabled)
    }
}

private struct NrcTownshipPicker: View {
    let townships: AsyncValue<[NrcTownship]>
    let selected: NrcTownship?
    let onSelected: (NrcTownship) -> Void

    var body: some View {
        let options = townships.valueOrNull ?? []
        let enabled = townships.hasValue && !options.isEmpty
        // The compact NRC row follows the familiar English township notation
        // (for example, `/ KHALAPHA`) while the picker still shows full details.
        let englishShort = selected.map { BookingDetailScreenState.trim($0.shortEn) } ?? ""
        let label = !englishShort.isEmpty
            ? englishShort
            : (selected.map { BookingDetailScreenState.trim($0.short) } ?? "")
        let text = !label.isEmpty
            ? label
            : townships.hasError
            ? "Unavailable"
            : townships.isLoading
            ? "Loading..."
            : "Township"
        Button {
            Task { await open(options) }
        } label: {
            HStack(spacing: 0) {
                Text(text)
                    .textStyle(AppTypography.body(
                        12.5,
                        weight: !label.isEmpty ? .w700 : .w500,
                        color: !label.isEmpty ? AppColors.textPrimary : AppColors.textTertiary
                    ))
                    .dynamicTypeSize(.large)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if townships.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(AppColors.primary)
                        .frame(width: 14, height: 14)
                } else {
                    Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 17,
                        color: enabled ? AppColors.textSecondary : AppColors.textTertiary
                    )
                }
            }
            .padding(.leading, 7)
            .padding(.trailing, 3)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.ink(radius: 4))
        .disabled(!enabled)
    }

    private func open(_ options: [NrcTownship]) async {
        let township: NrcTownship? = await showModalBottomSheet(
            isScrollControlled: true,
            backgroundColor: AppColors.surface,
            topRadius: 24
        ) { _ in
            NrcTownshipPickerSheet(townships: options, selected: selected)
        }
        if let township { onSelected(township) }
    }
}

private struct NrcTypePicker: View {
    private static let labels: [(key: String, value: String)] = [
        (key: "N", value: "(N) နိုင်"),
        (key: "E", value: "(E) ဧည့်"),
        (key: "P", value: "(P) ပြု"),
        (key: "T", value: "(T) သာသနာ့"),
        (key: "S", value: "(S) သွေးနှော"),
        (key: "TH", value: "(TH) ယာယီ"),
    ]

    let value: String
    let onChanged: (String) -> Void

    var body: some View {
        Menu {
            ForEach(Self.labels.indices, id: \.self) { index in
                let key = Self.labels[index].key
                Button("(\(key))") { onChanged(key) }
            }
        } label: {
            HStack(spacing: 0) {
                Text("(\(value))")
                    .textStyle(AppTypography.body(12.5, weight: .w600))
                    .dynamicTypeSize(.large)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textSecondary)
            }
            .padding(.leading, 6)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
    }
}

/// Searchable full-width township chooser. Keeping it in a bottom sheet means
/// the complete compact NRC value remains visible before and after selection.
private struct NrcTownshipPickerSheet: View {
    let townships: [NrcTownship]
    let selected: NrcTownship?

    @Environment(\.dismissModal) private var dismissModal
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    private var filtered: [NrcTownship] {
        let query = BookingDetailScreenState.trim(searchText).lowercased()
        if query.isEmpty { return townships }
        return townships.filter { township in
            [township.short, township.shortEn, township.cityName]
                .contains { $0.lowercased().contains(query) }
        }
    }

    var body: some View {
        let townships = filtered
        VStack(spacing: 0) {
            VGap(10)
            Capsule()
                .fill(AppColors.border)
                .frame(width: 38, height: 4)
            HStack(spacing: 0) {
                Text("Select township")
                    .textStyle(AppTypography.heading(20))
                    .dynamicTypeSize(.large)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    dismissModal()
                } label: {
                    Icon(Icons.close_rounded, color: AppColors.textSecondary)
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(20, 16, 12, 12)
            searchField
                .padding(20, 0, 20, 12)
            MaterialDivider(height: 1, color: AppColors.dividerLight)
            Group {
                if townships.isEmpty {
                    Text("No townships match your search.")
                        .textStyle(AppTypography.body(13, color: AppColors.textSecondary))
                        .dynamicTypeSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(townships.enumerated()), id: \.offset) { index, township in
                                if index > 0 {
                                    MaterialDivider(height: 1, color: AppColors.dividerLight, indent: 20, endIndent: 20)
                                }
                                row(township)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: BookingDetailHelpers.sheetContentHeight(0.76))
        .task { searchFocused = true }
    }

    /// `_townshipSearchDecoration()`.
    private var searchField: some View {
        HStack(spacing: 0) {
            Icon(Icons.search_rounded, color: AppColors.textTertiary)
                .frame(width: 48)
            TextField(
                "",
                text: $searchText,
                prompt: Text("Search township or city")
                    .font(AppTypography.body(14).font)
                    .foregroundColor(AppColors.textPlaceholder)
            )
            .font(AppTypography.body(14).font)
            .foregroundStyle(AppColors.textPrimary)
            .tint(AppColors.primary)
            .textInputAutocapitalization(.never)
            .focused($searchFocused)
            .padding(.vertical, 15)
            .padding(.trailing, 14)
        }
        .frame(minHeight: 48)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.background))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(searchFocused ? AppColors.primary : AppColors.border, lineWidth: searchFocused ? 1.4 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { searchFocused = true }
    }

    private func row(_ township: NrcTownship) -> some View {
        let isSelected = township.id == selected?.id
        let label = townshipPopupLabel(township)
        return Button {
            dismissModal(township)
        } label: {
            HStack(spacing: 0) {
                // A township's city name must not be cut off. Let a long
                // Burmese or English name wrap to its full length rather than
                // ellipsizing it.
                Text(label)
                    .textStyle(AppTypography.body(
                        15,
                        weight: isSelected ? .w800 : .w600,
                        color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                        letterSpacing: 0.4
                    ))
                    .dynamicTypeSize(.large)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isSelected {
                    HGap(16)
                    Icon(Icons.check_circle_rounded, color: AppColors.primary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.ink)
    }
}

/// `short` is the NRC code stored with the booking; `cityName` is the human
/// readable township name. Show both, rather than losing the city whenever an
/// English short code is available.
private func townshipPopupLabel(_ township: NrcTownship) -> String {
    let short = BookingDetailScreenState.trim(township.short)
    let city = BookingDetailScreenState.trim(township.cityName)
    let english = BookingDetailScreenState.trim(township.shortEn)
    var parts: [String] = []
    if !short.isEmpty { parts.append(short) }
    if !city.isEmpty && city.lowercased() != short.lowercased() { parts.append(city) }
    let main = parts.joined(separator: " · ")
    if english.isEmpty || english.lowercased() == main.lowercased() {
        return main
    }
    return main.isEmpty ? english : "\(main) (\(english))"
}

// ── Phone number field ──────────────────────────────────────────────────────

private struct PhoneCountry {
    let name: String
    let dialCode: String
    let flagCode: String

    init(_ name: String, _ dialCode: String, _ flagCode: String) {
        self.name = name
        self.dialCode = dialCode
        self.flagCode = flagCode
    }
}

private let phoneCountries: [PhoneCountry] = [
    PhoneCountry("Myanmar", "+95", "mm"),
    PhoneCountry("Australia", "+61", "au"),
    PhoneCountry("Bangladesh", "+880", "bd"),
    PhoneCountry("Brunei", "+673", "bn"),
    PhoneCountry("Cambodia", "+855", "kh"),
    PhoneCountry("China", "+86", "cn"),
    PhoneCountry("France", "+33", "fr"),
    PhoneCountry("Germany", "+49", "de"),
    PhoneCountry("Hong Kong", "+852", "hk"),
    PhoneCountry("India", "+91", "in"),
    PhoneCountry("Indonesia", "+62", "id"),
    PhoneCountry("Italy", "+39", "it"),
    PhoneCountry("Japan", "+81", "jp"),
    PhoneCountry("Laos", "+856", "la"),
    PhoneCountry("Malaysia", "+60", "my"),
    PhoneCountry("Nepal", "+977", "np"),
    PhoneCountry("Netherlands", "+31", "nl"),
    PhoneCountry("New Zealand", "+64", "nz"),
    PhoneCountry("Pakistan", "+92", "pk"),
    PhoneCountry("Philippines", "+63", "ph"),
    PhoneCountry("Qatar", "+974", "qa"),
    PhoneCountry("Russia", "+7", "ru"),
    PhoneCountry("Saudi Arabia", "+966", "sa"),
    PhoneCountry("Singapore", "+65", "sg"),
    PhoneCountry("South Korea", "+82", "kr"),
    PhoneCountry("Spain", "+34", "es"),
    PhoneCountry("Sri Lanka", "+94", "lk"),
    PhoneCountry("Switzerland", "+41", "ch"),
    PhoneCountry("Taiwan", "+886", "tw"),
    PhoneCountry("Thailand", "+66", "th"),
    PhoneCountry("United Arab Emirates", "+971", "ae"),
    PhoneCountry("United Kingdom", "+44", "gb"),
    PhoneCountry("United States / Canada", "+1", "us"),
    PhoneCountry("Vietnam", "+84", "vn"),
]

/// One joined phone control: a dial-code selector on the left and the local
/// number on the right. Its code-then-chevron order matches the Title field,
/// while the selected dial code remains separate for the booking API.
private struct PhoneField: View {
    @Binding var text: String
    let countryCode: String
    let onCountryCodeChanged: (String) -> Void
    var errorText: String? = nil

    var body: some View {
        let country = phoneCountries.first { $0.dialCode == countryCode } ?? phoneCountries[0]
        // `_phoneNumberDecoration`: the prefix replaces the left padding, so
        // the number and the error line start right after it.
        BookingFormTextField(
            text: $text,
            hint: "9123456789",
            keyboardType: .phonePad,
            errorText: errorText,
            formatter: BookingDetailHelpers.digitsOnly,
            contentPadding: EdgeInsets(top: 14, leading: 0, bottom: 14, trailing: 12),
            errorLeading: 0,
            prefix: AnyView(
                PhonePrefix(country: country) {
                    Task { await pickCountryCode() }
                }
            )
        )
    }

    private func pickCountryCode() async {
        let selected: String? = await showModalBottomSheet(
            isScrollControlled: true,
            backgroundColor: AppColors.surface,
            topRadius: 22
        ) { _ in
            PhoneCountryPickerSheet(selectedCode: countryCode)
        }
        if let selected { onCountryCodeChanged(selected) }
    }
}

private struct PhonePrefix: View {
    let country: PhoneCountry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                Text(country.dialCode)
                    .textStyle(AppTypography.body(13.5, weight: .w600, color: AppColors.textPrimary))
                    .dynamicTypeSize(.large)
                HGap(2)
                Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary)
                HGap(10)
                Rectangle()
                    .fill(AppColors.divider)
                    .frame(width: 1, height: 24)
            }
            .padding(.leading, 10)
            .frame(minHeight: formControlHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.ink(radius: fieldRadius))
        .accessibilityLabel("Change country code, \(country.name) \(country.dialCode)")
    }
}

/// A full-width picker avoids squeezing long country names into the compact
/// dial-code control beside the mobile-number field.
private struct PhoneCountryPickerSheet: View {
    let selectedCode: String

    @Environment(\.dismissModal) private var dismissModal

    var body: some View {
        VStack(spacing: 0) {
            VGap(10)
            Capsule()
                .fill(AppColors.border)
                .frame(width: 38, height: 4)
            HStack(spacing: 0) {
                Text("Select country code")
                    .textStyle(AppTypography.heading(18))
                    .dynamicTypeSize(.large)
                Spacer(minLength: 0)
                Text("\(phoneCountries.count) countries")
                    .textStyle(AppTypography.body(12, color: AppColors.textSecondary))
                    .dynamicTypeSize(.large)
            }
            .padding(20, 16, 20, 12)
            MaterialDivider(height: 1, color: AppColors.dividerLight)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(phoneCountries.enumerated()), id: \.offset) { index, country in
                        if index > 0 {
                            MaterialDivider(height: 1, color: AppColors.dividerLight, indent: 64)
                        }
                        row(country)
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: BookingDetailHelpers.sheetContentHeight(0.72))
    }

    private func row(_ country: PhoneCountry) -> some View {
        let isSelected = country.dialCode == selectedCode
        return Button {
            dismissModal(country.dialCode)
        } label: {
            HStack(spacing: 0) {
                NetworkImage(
                    "https://flagcdn.com/w40/\(country.flagCode).png",
                    width: 24,
                    height: 16,
                    fit: .cover
                ) {
                    Color.clear
                } error: {
                    Color.clear
                }
                .clipShape(RoundedRectangle(cornerRadius: 2))
                HGap(16)
                Text(country.name)
                    .textStyle(AppTypography.body(
                        14,
                        weight: isSelected ? .w700 : .w500,
                        color: isSelected ? AppColors.primaryDark : AppColors.textPrimary
                    ))
                    .dynamicTypeSize(.large)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HGap(16)
                Text(country.dialCode)
                    .textStyle(AppTypography.body(
                        14,
                        weight: .w700,
                        color: isSelected ? AppColors.primary : AppColors.textSecondary
                    ))
                    .dynamicTypeSize(.large)
                if isSelected {
                    HGap(10)
                    Icon(Icons.check_circle_rounded, size: 18, color: AppColors.primary)
                }
            }
            .padding(.horizontal, 20)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.ink)
    }
}

// ── Fare breakdown helpers ────────────────────────────────────────────────────

/// One label ↔ value line inside the fare breakdown panel. `sign` prefixes the
/// amount with a "+" (added charge) or "−" (deduction) as in the reference.
private struct AmountRow: View {
    let label: String
    let value: String
    var sign = ""

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .textStyle(AppTypography.body(13, weight: .w500, color: AppColors.textSecondary))
                .frame(maxWidth: .infinity, alignment: .leading)
            HGap(12)
            Text(sign.isEmpty ? value : "\(sign) \(value)")
                .textStyle(AppTypography.body(13, weight: .w500, color: AppColors.textSecondary))
        }
    }
}

// ── Booking-process alert (non-MAI reservation form) ────────────────────────

/// A short, friendly alert explaining that non-MAI airlines are reservation
/// (book-then-pay-at-office), shown above the Booking Form.
private struct BookingProcessAlert: View {
    let airline: String

    var body: some View {
        let amber = AppColors.accent
        let points = [
            "\(airline) tickets are reserved through our office — not instant "
                + "online payment.",
            "Send your details, we'll hold your seat and confirm by phone. "
                + "Pay when you visit our office.",
        ]
        VStack(alignment: .leading, spacing: 0) {
            // Title row — amber icon badge + heading.
            HStack(spacing: 0) {
                Icon(Icons.info_outline_rounded, size: 18, color: amber)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(amber.withValues(alpha: 0.14)))
                HGap(10)
                Text(LocaleKeys.booking_reservation_not_instant_payment.tr())
                    .textStyle(AppTypography.body(14, weight: .w700, color: AppColors.textPrimary))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            VGap(12)
            // Bulleted list of how the reservation works.
            ForEach(points.indices, id: \.self) { i in
                if i > 0 { VGap(8) }
                HStack(alignment: .top, spacing: 0) {
                    Circle()
                        .fill(amber)
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                    HGap(10)
                    Text(points[i])
                        .textStyle(AppTypography.body(12.5, color: AppColors.textSecondary, height: 1.4))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        // 16pt padding plus the 1pt border a Container adds to it.
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .boxDecoration(
            color: AppColors.surface,
            radius: 14,
            borderColor: AppColors.border,
            shadows: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 14,
                    offset: Offset(0, 4)
                ),
            ]
        )
    }
}
