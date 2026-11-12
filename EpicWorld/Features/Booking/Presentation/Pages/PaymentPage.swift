// Port of lib/features/booking/presentation/pages/payment_page.dart
import SwiftUI
import UIKit

// ── Retained checkout components ─────────────────────────────────────────────
//
// SmartPay's hosted page now owns method selection, the QR, and the PIN pad,
// so everything in the "Retained checkout components" section at the bottom of
// this file is unreferenced design reference from the simulated checkout. It
// is kept (rather than deleted) so the previous screens can still be read next
// to the new flow. Safe to delete wholesale once nobody needs it.
//
// Every Dart-private widget of this file is nested in `PaymentPage` (rather
// than file-private at top level) because `_DottedLine` here would otherwise
// clash with the shared `DottedLine` in TicketCardShell.swift.

struct PaymentPage: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router
    @Environment(\.routeEntryID) private var entryID
    @Environment(\.scenePhase) private var scenePhase

    @State private var screenState: PaymentScreenState?

    init() {}

    var body: some View {
        Group {
            if let screenState {
                PaymentScreenView(state: screenState)
            } else {
                // `initState` has not run yet: nothing to pay for this frame.
                Scaffold(backgroundColor: AppColors.background) { EmptyView() }
            }
        }
        .onAppear {
            // `initState`, once.
            guard screenState == nil else { return }
            let created = PaymentScreenState(container: container, router: router, entryID: entryID)
            screenState = created
            created.initState()
        }
        .onDisappear {
            // `dispose`: only when the route itself is gone, not when another
            // route (Login, say) is pushed over it.
            if let screenState, !screenState.isRouteAlive { screenState.dispose() }
        }
        // `WidgetsBindingObserver.didChangeAppLifecycleState`.
        .onChange(of: scenePhase) { _, phase in
            screenState?.didChangeAppLifecycleState(phase)
        }
    }
}

// MARK: - Constants (Dart top-level `_k…`)

extension PaymentPage {
    /// Redemption rate for Epic Member loyalty points: 1 pt = 1 MMK.
    static let kMmkPerPoint = 1

    /// Amounts inside the payment gateway sheet/PIN pad are shown the way the
    /// wallet gateway prints them, e.g. "94,650.00".
    fileprivate static let kGatewayAmount = NumberFormat("#,##0.00")

    /// Payee shown on the gateway sheet and the PIN pad.
    fileprivate static let kGatewayMerchant = "Epic World"

    // Gateway (wallet) chrome — neutral surfaces, brand green for the actions.
    fileprivate static let kGatewayAccent = AppColors.primary
    fileprivate static let kGatewaySurface = Color(0xFFF2F2F7)

    /// Merchant (payee) account name shown on the MMQR card. Kept as data —
    /// drawn as a live text overlay rather than baked into the artwork — so it
    /// can change without re-exporting the image.
    fileprivate static let kMmqrAccountName = "EPIC WORLD CO., LTD."

    /// `Curves.easeOutCubic` over `seconds`.
    fileprivate static func easeOutCubic(_ seconds: Double) -> Animation {
        .timingCurve(0.215, 0.61, 0.355, 1, duration: seconds)
    }

    /// Dart `num.clamp(lower, upper).toDouble()`.
    fileprivate static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    /// `MediaQuery.of(context).padding.bottom`.
    @MainActor
    fileprivate static var safeAreaBottom: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
        return window?.safeAreaInsets.bottom ?? 0
    }
}

// MARK: - State (`_PaymentScreenState`)

extension PaymentPage {
    /// The payment screen's state and logic — Dart's `_PaymentScreenState`.
    /// Internal (not file-private) so the unit tests can drive it.
    @MainActor
    @Observable
    final class PaymentScreenState {
        /// Shows the "Add payment method" card (MMQR / card tiles + wallet
        /// grid) and its in-app MMQR scan flow. Set to false to drop the picker
        /// and pay through the wallet gateway sheet + PIN pad instead.
        static let kShowPaymentMethodCard = true

        var processing = false

        /// True once a payment intent has been created and the customer has
        /// been sent to SmartPay. The backend's status remains authoritative: a
        /// returned `PENDING` status lets the customer reopen SmartPay for the
        /// same hold.
        var awaitingSmartPayReturn = false

        /// Set only when `getPaymentStatus` says SmartPay has not taken a
        /// payment yet. It changes the bottom action from status checking to
        /// reopening the hosted checkout for the existing reservation.
        var canResumeSmartPay = false

        var pendingSmartPayPayment: PendingSmartPayPayment?

        /// Automatic verification attempts made since the customer came back.
        ///
        /// The backend ticketing a booking can lag SmartPay settling the charge
        /// by a few seconds, so a `PAID`-but-not-yet-ticketed answer is retried
        /// here rather than handed back to the customer as something to tap.
        var verifyAttempts = 0
        var verifyTimer: Task<Void, Never>?

        static let maxVerifyAttempts = 4
        static let verifyRetryDelay = Duration(seconds: 3)

        /// True while a verification is running or already queued — the pay
        /// button stays a spinner rather than inviting a tap that would
        /// duplicate it.
        var verifying: Bool { processing || verifyTimer != nil }
        var showAmountCard = true
        // The "You're not signed in" prompt (shown above the Amount Summary
        // while signed out) — hidden once the user dismisses it with the close
        // button.
        var signInDismissed = false

        /// `_promoController.text`.
        var promoText = ""
        var discount: Double = 0
        var appliedCode: String?
        var appliedPromo: PromoCodeCheckResponse?
        var applyingPromo = false

        // Epic Member Point selector: choosing Use stages the live point
        // balance; the server does the actual redemption only when Pay Now is
        // pressed.
        var pointsExpanded = false
        var pointsApplied = false
        var selectedPoints = 0

        // Once the backend has redeemed this booking, a failed/retried SmartPay
        // launch must not spend the same points a second time.
        var pointsRedeemedForBookingId: String?
        var redeemedPointsDiscount: Double?

        // The trip being paid for, snapshotted on entry. Leaving resets the
        // booking while this screen is still mounted for the exit animation —
        // reading the selection straight off the bloc would then blow up on a
        // null flight mid-exit.
        var outbound: TripOptionModel?
        var inbound: TripOptionModel?
        var baseTotal: Double = 0

        let container: AppContainer
        let router: AppRouter
        let entryID: UUID?
        @ObservationIgnored private var disposed = false

        init(container: AppContainer, router: AppRouter, entryID: UUID?) {
            self.container = container
            self.router = router
            self.entryID = entryID
        }

        /// The route this screen belongs to is still on the stack.
        var isRouteAlive: Bool {
            guard let entryID else { return true }
            return router.entries.contains { $0.id == entryID }
        }

        /// Dart `mounted`.
        var mounted: Bool { !disposed && isRouteAlive }

        func initState() {
            let booking = container.flightBookingBloc.state
            outbound = booking.selectedOutbound
            inbound = booking.selectedInbound
            baseTotal = booking.holdResponse?.total ?? 0
            if baseTotal <= 0 { baseTotal = booking.totalPrice }

            // Re-entering payment with a SmartPay attempt already in flight for
            // *this* reservation (the app was killed in a wallet app, say)
            // resumes waiting on it instead of creating a second payment for
            // the same booking.
            if let pending = PendingSmartPayPaymentStore.read(),
               pending.reference == booking.holdResponse?.reference {
                pendingSmartPayPayment = pending
                awaitingSmartPayReturn = true
            }

            restoreAppliedPromo(booking.holdResponse?.reference ?? "")

            // `myPoints` is shared by the account screens and may still hold
            // the result from an earlier visit. Payment must always use the
            // latest redeemable balance, so refresh it whenever this form
            // becomes active.
            Task { [weak self] in
                guard let self, self.mounted else { return }
                await self.refreshMemberPoints()
            }
        }

        func dispose() {
            disposed = true
            verifyTimer?.cancel()
            verifyTimer = nil
        }

        func refreshMemberPoints() async {
            if !container.authNotifier.state.isAuthenticated { return }
            do {
                container.myPoints.invalidate()
                _ = try await container.myPoints.future
            } catch {
                // Keep the locally restored profile balance as the graceful
                // fallback; `currentMemberPoints` already provides it when this
                // call fails.
            }
        }

        /// Puts a promotion the customer already applied to this reservation
        /// back on the form, so a reload does not quietly cost them their
        /// discount.
        ///
        /// The stored discount is re-clamped rather than trusted: it was
        /// calculated against the total at the time it was applied. The backend
        /// re-validates the code at `createPaymentIntent` regardless — this only
        /// restores what the screen was showing.
        func restoreAppliedPromo(_ reference: String) {
            guard let applied = AppliedPromoStore.read(reference) else { return }
            discount = PaymentPage.clamp(applied.discount, 0, baseTotal)
            appliedCode = applied.code
            appliedPromo = applied.promo
            promoText = applied.code
        }

        /// Remembers the promotion against the reservation it was validated for.
        func rememberAppliedPromo(_ promo: PromoCodeCheckResponse) async {
            let reference = container.flightBookingBloc.state.holdResponse?.reference ?? ""
            guard !reference.isEmpty, let code = appliedCode else { return }
            await AppliedPromoStore.save(
                AppliedPromo(reference: reference, code: code, discount: discount, promo: promo)
            )
        }

        /// Coming back from the browser — or from a wallet app it handed off to
        /// — is the moment worth re-asking the backend. With checkout running
        /// outside the app, this is how a finished payment gets noticed: the
        /// customer should find the success dialog waiting, not a button asking
        /// them to check.
        func didChangeAppLifecycleState(_ phase: ScenePhase) {
            if phase == .active {
                Task { await refreshMemberPoints() }
            }
            if phase == .active && awaitingSmartPayReturn && !verifying {
                // A fresh return earns a fresh budget of automatic attempts.
                verifyAttempts = 0
                Task { await checkPaymentStatus() }
            }
        }

        func applyPromo(_ baseTotal: Double) async {
            if pointsRedeemedForBookingId != nil {
                showPaymentError("Reward points are already redeemed for this booking.")
                return
            }
            let code = promoText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if code.isEmpty {
                showPaymentError("Enter a promo code.")
                return
            }

            let authUser = container.authNotifier.state.user
            let contactEmail = Dart.str(container.flightBookingBloc.state.holdRequest?.contact["email"])?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let email: String
            if let contactEmail, !contactEmail.isEmpty {
                email = contactEmail
            } else {
                email = authUser?.email.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            }
            if email.isEmpty {
                showPaymentError("A contact email is required to apply a promo code.")
                return
            }

            applyingPromo = true
            defer {
                if mounted { applyingPromo = false }
            }
            do {
                let service = container.promoCodeCallableService
                let subtotal = PaymentScreenState.subtotalForPromo(baseTotal)
                let response = try await withSession { accessToken in
                    try await service.checkPromoCode(
                        PromoCodeCheckRequest(
                            code: code,
                            accessToken: accessToken,
                            subtotal: subtotal,
                            email: email
                        )
                    )
                }
                if !mounted { return }
                let discount = PaymentPage.clamp(response.amount, 0, baseTotal)
                if !response.ok {
                    await clearPromo()
                    if !mounted { return }
                    showPaymentError(!response.message.isEmpty ? response.message : "Invalid promo code.")
                    return
                }

                self.discount = discount
                appliedCode = !response.code.isEmpty ? response.code : code
                appliedPromo = response
                // Promo codes and point redemption cannot be stacked.
                pointsApplied = false
                pointsExpanded = false
                selectedPoints = 0
                await rememberAppliedPromo(response)
                if !mounted { return }
                showNotice(
                    !response.message.isEmpty
                        ? response.message
                        : "Promo \(appliedCode ?? "null") applied — saved \(Formatters.price(discount))"
                )
            } catch {
                if !mounted { return }
                await clearPromo()
                if !mounted { return }
                showPaymentError(ApiException.messageFrom(error))
            }
        }

        /// Drops the applied promotion from the screen and from storage
        /// together, so a reload cannot resurrect a discount the customer just
        /// lost or removed.
        func clearPromo(clearField: Bool = false) async {
            if mounted {
                discount = 0
                appliedCode = nil
                appliedPromo = nil
                if clearField { promoText = "" }
            }
            await AppliedPromoStore.clear()
        }

        /// Value of the staged or redeemed reward points, capped at what is
        /// still owed after the promo so the grand total can never go negative.
        /// Promo codes and points cannot be stacked, so this is 0 while a code
        /// is on.
        var rewardValue: Double {
            guard pointsApplied && appliedCode == nil else { return 0 }
            return PaymentPage.clamp(
                redeemedPointsDiscount ?? Double(selectedPoints * PaymentPage.kMmkPerPoint),
                0,
                baseTotal - discount
            )
        }

        /// `'${Formatters.grouped(points)} points'`, as the reward-points
        /// field and its dropdown print a balance.
        static func pointsLabel(_ points: Int) -> String {
            "\(Formatters.grouped(points)) points"
        }

        static func subtotalForPromo(_ subtotal: Double) -> String {
            if subtotal == subtotal.rounded() {
                return String(Int(subtotal.rounded()))
            }
            return String(format: "%.2f", subtotal)
        }

        func showNotice(_ message: String) {
            if !mounted { return }
            SnackBarCenter.shared.show(message, backgroundColor: AppColors.primaryDark, floating: true)
        }

        func onPromoChanged(_ value: String) {
            if let appliedCode,
               value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() != appliedCode {
                // Editing the field un-applies the promotion, so the stored copy
                // has to go with it.
                Task { await clearPromo() }
                return
            }
            // `setState(() {})`: Observation already re-renders on the edit.
        }

        func removePromo() {
            Task { await clearPromo(clearField: true) }
        }

        func usePoints(_ availablePoints: Int) {
            if appliedCode != nil {
                showPaymentError("Remove the promo code before using reward points.")
                return
            }
            if availablePoints <= 0 {
                showPaymentError("No reward points are available to redeem.")
                return
            }
            pointsApplied = true
            pointsExpanded = false
            selectedPoints = availablePoints
            redeemedPointsDiscount = nil
        }

        func removePoints() {
            if pointsRedeemedForBookingId != nil {
                showPaymentError("Reward points are already redeemed for this booking.")
                return
            }
            pointsApplied = false
            pointsExpanded = false
            selectedPoints = 0
            redeemedPointsDiscount = nil
        }

        func pay(_ booking: FlightBookingState, _ total: Double) async {
            // The traveller-details screen owns the one `holdFlight` call. By
            // this point the confirmation screen has shown its result, so
            // payment must use that reservation instead of reserving the same
            // seats again.
            guard let draft = booking.holdRequest, let hold = booking.holdResponse else {
                showPaymentError(
                    "Your reservation details are missing. Please go back and reserve your seats again."
                )
                return
            }

            let reference = hold.reference.trimmingCharacters(in: .whitespacesAndNewlines)
            let email = Dart.str(draft.contact["email"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if reference.isEmpty {
                showPaymentError("Your booking reference is missing. Please reserve your seats again.")
                return
            }
            if email.isEmpty {
                showPaymentError("A contact email is required to start payment.")
                return
            }

            processing = true
            do {
                let promoUsed = appliedCode?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                let shouldRedeemPoints = pointsApplied
                    && !promoUsed
                    && selectedPoints > 0
                    && pointsRedeemedForBookingId != hold.bookingId
                if shouldRedeemPoints {
                    if hold.bookingId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        throw StateError("Your booking ID is missing. Reward points cannot be redeemed.")
                    }
                    let memberService = container.memberRemoteService
                    let bookingId = hold.bookingId
                    let points = String(selectedPoints)
                    let redemption = try await withSession { accessToken in
                        try await memberService.redeemPoints(
                            RedeemPointsRequest(accessToken: accessToken, bookingId: bookingId, points: points)
                        )
                    }
                    if !redemption.ok {
                        throw StateError("Reward points could not be redeemed.")
                    }
                    if !mounted { return }
                    pointsRedeemedForBookingId = hold.bookingId
                    selectedPoints = redemption.redeemed
                    redeemedPointsDiscount = PaymentPage.clamp(redemption.discount, 0, baseTotal)
                    pointsApplied = redemption.redeemed > 0 || redemption.discount > 0
                    // The next screen that displays the member balance must not
                    // reuse the pre-redemption `/myPoints` result.
                    container.myPoints.invalidate()
                }

                let smartPay = container.smartPayCallableService
                let promoCode = appliedCode ?? ""
                let intent = try await withSession { accessToken in
                    try await smartPay.createPaymentIntent(
                        CreatePaymentIntentRequest(
                            reference: reference,
                            accessToken: accessToken,
                            email: email,
                            promoCode: promoCode
                        )
                    )
                }

                // Only ever hand a link to the browser that the backend vouched
                // for and that is actually TLS-protected — a payment page
                // reached over http, or a blank URL from a failed intent, is not
                // a payment page.
                let paymentUri = URL(string: intent.paymentUrl)
                guard intent.ok, let paymentUri, paymentUri.scheme?.lowercased() == "https" else {
                    throw StateError(intent.failureMessage)
                }

                // Recorded before the customer leaves, so the payment can still
                // be verified if the app never gets a clean return.
                let pending = PendingSmartPayPayment(
                    reference: reference,
                    email: email,
                    merchantOrderNo: intent.merchantOrderNo,
                    startedAt: DateTime.now().toUtc()
                )
                await PendingSmartPayPaymentStore.save(pending)
                if !mounted { return }
                pendingSmartPayPayment = pending
                awaitingSmartPayReturn = true
                canResumeSmartPay = false
                processing = false

                await openCheckout(paymentUri)
            } catch {
                if !mounted { return }
                processing = false
                showPaymentError(ApiException.messageFrom(error))
            }
        }

        /// Hands SmartPay's hosted checkout to the device's own browser.
        ///
        /// It opens as a separate app, so Epic World goes to the background and
        /// the payment result is picked up on resume (see
        /// `didChangeAppLifecycleState`) or from the "Check payment status"
        /// button. (The Flutter web branch, which navigates the current tab,
        /// has no iOS equivalent.)
        ///
        /// The browser, not an embedded web view, is deliberate: it brings the
        /// device's full certificate handling and the customer's saved cards
        /// and wallet sessions, and it shows them a real address bar on the
        /// page where they type card details.
        func openCheckout(_ paymentUri: URL) async {
            // `launchUrl(mode: externalApplication)` never throws here; a
            // refusal comes back as `false`.
            let launched = await ContactLauncher.open(paymentUri)
            // Launching is the only part the app controls. Everything after
            // this happens in the browser, and the reservation stays pending
            // until `getPaymentStatus` says otherwise.
            if launched || !mounted { return }
            await abandonCheckout("Could not open SmartPay. Please try again.")
        }

        /// Drops a checkout that never reached SmartPay, so the pay button
        /// comes back instead of the "check status" one.
        func abandonCheckout(_ message: String) async {
            verifyTimer?.cancel()
            verifyTimer = nil
            verifyAttempts = 0
            await PendingSmartPayPaymentStore.clear()
            if !mounted { return }
            pendingSmartPayPayment = nil
            awaitingSmartPayReturn = false
            canResumeSmartPay = false
            showPaymentError(message)
        }

        /// Asks the backend what actually happened, and finishes the booking
        /// only if it says the charge settled *and* the ticket was issued.
        ///
        /// Deliberately event-driven — the checkout closing, an app resume, or
        /// a tap on "Check payment status" — rather than a polling loop.
        /// SmartPay reports the payment to the backend over its own
        /// `smartpayCallback` webhook, so there is nothing the client could
        /// usefully poll faster than the customer returning.
        func checkPaymentStatus() async {
            if processing { return }
            // Any queued attempt is superseded by this one.
            verifyTimer?.cancel()
            verifyTimer = nil
            guard let pending = pendingSmartPayPayment ?? PendingSmartPayPaymentStore.read() else {
                if mounted { showPaymentError("No pending SmartPay payment was found.") }
                return
            }

            let booking = container.flightBookingBloc.state
            guard let hold = booking.holdResponse, let draft = booking.holdRequest else {
                showPaymentError(
                    "Your booking details are no longer available. Open booking history "
                        + "to check the payment."
                )
                return
            }

            processing = true
            do {
                let service = container.smartPayCallableService
                let status = try await withSession { accessToken in
                    try await service.getPaymentStatus(
                        GetPaymentStatusRequest(
                            reference: pending.reference,
                            accessToken: accessToken,
                            email: pending.email
                        )
                    )
                }
                if !mounted { return }

                if status.isSuccessful {
                    await PendingSmartPayPaymentStore.clear()
                    if !mounted { return }
                    pendingSmartPayPayment = nil
                    awaitingSmartPayReturn = false
                    canResumeSmartPay = false
                    processing = false
                    await finishBooking(
                        booking,
                        // Without a reported amount, what was charged is the
                        // discounted grand total this screen asked for.
                        status.amount > 0 ? status.amount : baseTotal - discount - rewardValue,
                        hold,
                        draft,
                        paidCurrency: status.currency
                    )
                    return
                }

                if status.isTerminalFailure {
                    await PendingSmartPayPaymentStore.clear()
                    if !mounted { return }
                    pendingSmartPayPayment = nil
                    awaitingSmartPayReturn = false
                    canResumeSmartPay = false
                    processing = false
                    showPaymentError(status.displayMessage)
                    return
                }

                // A customer who backed out of SmartPay before it charged them
                // is not stuck on a status screen: request another hosted link
                // for this same booking when they tap Resume payment. A paid
                // charge whose ticket is still issuing, on the other hand, must
                // stay in verification mode so it cannot be charged twice.
                awaitingSmartPayReturn = true
                canResumeSmartPay = status.canResumePayment
                processing = false
                if status.canResumePayment { return }

                // Still in flight, or paid with ticketing not finished. Keep
                // checking a short while longer rather than making the customer
                // chase it.
                if verifyAttempts < PaymentScreenState.maxVerifyAttempts {
                    verifyAttempts += 1
                    verifyTimer?.cancel()
                    verifyTimer = Task { [weak self] in
                        try? await Task.sleep(for: PaymentScreenState.verifyRetryDelay)
                        guard let self, !Task.isCancelled else { return }
                        self.verifyTimer = nil
                        if self.mounted {
                            Task { await self.checkPaymentStatus() }
                        }
                    }
                    return
                }
                // Out of automatic attempts: say what the backend last reported
                // and leave the button as a manual retry.
                showNotice(status.displayMessage)
            } catch {
                if !mounted { return }
                processing = false
                showPaymentError(ApiException.messageFrom(error))
            }
        }

        /// Last resort after the automatic attempts are spent — a fresh budget
        /// and another ask.
        func retryVerification() {
            verifyAttempts = 0
            Task { await checkPaymentStatus() }
        }

        /// Runs an authenticated SmartPay call against a session token that is
        /// still alive, and retries once on a freshly renewed session when the
        /// backend rejects it anyway.
        ///
        /// Checkout is the longest gap in the app between two calls — the
        /// customer can sit on a hosted payment page for as long as they like —
        /// so this is where an access token is most likely to die mid-flow.
        func withSession<T>(_ call: @escaping (String) async throws -> T) async throws -> T {
            try await container.authNotifier.withValidAccessToken { accessToken in
                try await call(accessToken)
            }
        }

        func showPaymentError(_ message: String) {
            if !mounted { return }
            SnackBarCenter.shared.show(message, backgroundColor: AppColors.error, floating: true)
        }

        /// Removes focus from the promo field when the traveller taps elsewhere
        /// on the payment page, which also closes the software keyboard.
        func dismissKeyboard() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }

        // Registers the server-verified ticket locally, shows the success
        // pop-up, then moves to the completed screen. Only ever reached once
        // `getPaymentStatus` has confirmed the backend both settled the charge
        // and issued the ticket.
        func finishBooking(
            _ booking: FlightBookingState,
            _ total: Double,
            _ hold: FlightHoldResponse,
            _ request: FlightHoldRequest,
            paidCurrency: String = ""
        ) async {
            guard let outbound else { return }

            let bookingRef: String
            if !hold.reference.isEmpty {
                bookingRef = hold.reference
            } else if !hold.pnr.isEmpty {
                bookingRef = hold.pnr
            } else {
                bookingRef = "EW-\(String(UUID().uuidString.lowercased().prefix(6)).uppercased())"
            }
            let passengerName = Dart.str(request.contact["fullName"])?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            // The travellers exactly as they were typed on the Traveller
            // Information form and sent to `holdFlight` — names, titles,
            // passport/NRC — plus the one contact phone the form collects for
            // the whole booking. The e-ticket prints these, so they have to be
            // the customer's own values rather than anything reconstructed here.
            let contactPhone = [
                Dart.str(request.contact["countryCode"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                Dart.str(request.contact["phone"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            ]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            let passengers = request.passengers.map { passenger in
                TicketPassenger.fromHoldRequest(passenger, phone: contactPhone)
            }
            let currency: String
            if !paidCurrency.isEmpty {
                currency = paidCurrency
            } else {
                currency = !hold.currency.isEmpty ? hold.currency : outbound.currency
            }
            let ticket = TicketModel(
                id: !hold.bookingId.isEmpty ? hold.bookingId : UUID().uuidString.lowercased(),
                bookingReference: bookingRef,
                outbound: outbound,
                inbound: inbound,
                passengerName: passengerName?.isEmpty == false ? passengerName! : "Passenger",
                seatCount: !passengers.isEmpty ? passengers.count : booking.totalTravellers,
                totalPaid: total > 0 ? total : hold.total,
                currency: currency,
                issuedAt: DateTime.now(),
                qrPayload: "\(hold.pnr)|\(bookingRef)",
                pnr: hold.pnr,
                contactName: passengerName ?? "",
                passengers: passengers,
                // Carried so the confirmation's amount summary can show the
                // saving.
                discount: discount + rewardValue,
                promotion: discount,
                promoCode: appliedCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            )

            if !mounted { return }
            container.ticketNotifier.addTicket(ticket)
            container.flightBookingBloc.add(.bookingCompleted)
            // The booking has moved from held to ticketed, so travel history is
            // stale. Invalidated here rather than back on the History tile that
            // started the payment: this screen leaves by replacing the stack, so
            // that tile's `push` never returns to do it.
            container.myBookingHistory.invalidate()
            // The promotion has been spent on this booking; it must not be
            // waiting on the form for the next one.
            await AppliedPromoStore.clear()
            // A guest's copy of this booking lives on the device, and it still
            // says "Seats held". No-op for anyone signed in, whose history comes
            // from the server.
            await GuestBookingStore.updateStatus(bookingRef, GuestBookingStatus.confirmed)
            if !mounted { return }

            let orderDate = DateFormat("d MMMM yyyy").format(ticket.issuedAt)
            let _: Bool? = await showDialog(
                barrierDismissible: false,
                barrierColor: Colors.black.withValues(alpha: 0.55)
            ) { dismiss in
                PaymentSuccessDialog(
                    ticket: ticket,
                    orderDate: orderDate,
                    customerName: "Mr \(ticket.passengerName)",
                    // SmartPay owns the method choice now, so the app can only
                    // honestly name the gateway, not the wallet or card behind it.
                    paymentLabel: "SmartPay",
                    grandTotal: total,
                    onContinue: { dismiss(nil) }
                )
            }

            if !mounted { return }
            router.replace(.bookingCompleted(ticket: ticket))
        }

        /// Asks before abandoning a payment that is already set up.
        ///
        /// Leaving loses the seat hold and everything entered on the way here,
        /// so the back gesture and the header's back arrow both route through
        /// this rather than popping straight out.
        func confirmLeavePayment() async {
            let leave: Bool? = await showDialog(
                barrierDismissible: false,
                // showCupertinoDialog's barrier (kCupertinoModalBarrierColor).
                barrierColor: Color(0x33000000)
            ) { _ in
                IosConfirmDialog(
                    title: LocaleKeys.booking_leave_payment_title.tr(),
                    message: LocaleKeys.booking_leave_payment_message.tr(),
                    confirmLabel: LocaleKeys.common_yes.tr(),
                    cancelLabel: LocaleKeys.common_no.tr()
                )
            }
            if !mounted || leave != true { return }

            // Yes → straight to the Home tab, with the half-finished booking
            // cleared so the next search starts fresh. The promotion and any
            // half-started payment belonged to the reservation being abandoned,
            // so they go too.
            await AppliedPromoStore.clear()
            await PendingSmartPayPaymentStore.clear()
            if !mounted { return }
            container.flightBookingBloc.add(.bookingReset)
            container.mainShellTab.value = 0
            router.replaceAll([.mainShell])
        }

        /// The held contact's `key`, trimmed, or nil when blank.
        static func contactValue(_ contact: JSON?, _ key: String) -> String? {
            let value = Dart.str(contact?[key])?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let value, !value.isEmpty { return value }
            return nil
        }
    }
}

// MARK: - Build

extension PaymentPage {
    fileprivate struct PaymentScreenView: View {
        let state: PaymentScreenState

        @Environment(AppContainer.self) private var container
        @Environment(AppRouter.self) private var router

        init(state: PaymentScreenState) {
            self.state = state
        }

        var body: some View {
            let booking = container.flightBookingBloc.state
            // Only possible if this screen is reached without a selected flight
            // (or rebuilt after the selection was cleared); there is nothing to
            // pay for.
            if let outbound = state.outbound {
                content(booking: booking, outbound: outbound)
                    // The pop is intercepted so the back gesture and the header
                    // arrow both ask before discarding the payment; leaving is
                    // done by the handler.
                    .popScope(canPop: false) { didPop in
                        if didPop { return }
                        Task { await state.confirmLeavePayment() }
                    }
            } else {
                Scaffold(backgroundColor: AppColors.background) { EmptyView() }
            }
        }

        @ViewBuilder
        private func content(booking: FlightBookingState, outbound: TripOptionModel) -> some View {
            let baseTotal = state.baseTotal

            // Redeemable Epic Member points, capped at what is still owed after
            // the promo discount so the grand total can never go negative.
            let signedIn = container.authNotifier.state.isAuthenticated
            let memberPoints = container.currentMemberPoints
            let afterPromo = baseTotal - state.discount
            let rewardValue = state.rewardValue
            let total = afterPromo - rewardValue
            let heldContact = booking.holdRequest?.contact
            let contactName = PaymentScreenState.contactValue(heldContact, "fullName")
            let contactPhone = PaymentScreenState.contactValue(heldContact, "phone")
            let contactEmail = PaymentScreenState.contactValue(heldContact, "email")
            let travellers = booking.totalTravellers
            let travellerWord = travellers == 1 ? "Traveller" : "Travellers"
            let subtitle = "\(Formatters.shortDate(booking.departDate))  ·  \(travellers) \(travellerWord)"

            Scaffold(
                backgroundColor: AppColors.background,
                appBar: { EmptyView() },
                bottomNavigationBar: { buildBottomBar(booking: booking, total: total) }
            ) {
                VStack(spacing: 0) {
                    CheckoutStepHeader(
                        // Pinned to this screen's own step so the header doesn't
                        // jump back a stage while the pop animation plays out.
                        stage: .payment,
                        fromCode: booking.fromLocation.code,
                        toCode: booking.toLocation.code,
                        subtitle: subtitle,
                        onBack: { Task { await state.confirmLeavePayment() } }
                    )
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // Gentle nudge to sign in — only while signed out and
                            // not yet dismissed, sitting above the Amount Summary
                            // card.
                            if !signedIn && !state.signInDismissed {
                                buildSignInPrompt()
                                VGap(16)
                            }
                            buildAmountSummaryCard(
                                baseTotal: baseTotal,
                                grandTotal: total,
                                booking: booking,
                                memberPoints: memberPoints,
                                rewardValue: rewardValue,
                                signedIn: signedIn
                            )
                            VGap(20)
                            if PaymentScreenState.kShowPaymentMethodCard {
                                buildPaymentSection()
                                VGap(20)
                            }
                            // Trip summary now sits below the payment method card.
                            TripSummaryCard(
                                outbound: outbound,
                                inbound: state.inbound,
                                contactName: contactName,
                                contactPhone: contactPhone,
                                contactEmail: contactEmail,
                                initiallyExpanded: false
                            )
                            VGap(20)
                        }
                        .padding(AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.screenH)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { state.dismissKeyboard() }
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
                .background {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { state.dismissKeyboard() }
                }
            }
        }

        // ── "You're not signed in" prompt (signed-out only) ───────────────────

        private func buildSignInPrompt() -> some View {
            let amber = AppColors.accent
            return VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                    Icon(Icons.login_rounded, size: 22, color: amber)
                        .frame(width: 44, height: 44)
                        .boxDecoration(
                            color: amber.withValues(alpha: 0.10),
                            circle: true,
                            borderColor: amber.withValues(alpha: 0.55),
                            borderWidth: 1.4
                        )
                    HGap(12)
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top, spacing: 0) {
                            Text("You're not signed in")
                                .textStyle(AppTypography.body(14.5, weight: .w700, color: AppColors.textPrimary))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Icon(Icons.close_rounded, size: 18, color: AppColors.textTertiary)
                                .contentShape(Rectangle())
                                .onTapGesture { state.signInDismissed = true }
                        }
                        VGap(3)
                        Text(LocaleKeys.booking_log_in_to_save_this_booking.tr())
                            .textStyle(AppTypography.body(12.5, color: AppColors.textSecondary, height: 1.4))
                            .lineLimit(2)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                VGap(12)
                Button {
                    router.push(.login(popOnSuccess: true))
                } label: {
                    Text(LocaleKeys.booking_log_in.tr())
                        .textStyle(AppTypography.body(13, weight: .w700, color: Colors.white))
                }
                .buttonStyle(ElevatedButtonStyle(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumHeight: 36,
                    cornerRadius: 10,
                    padding: EdgeInsets(top: 0, leading: 22, bottom: 0, trailing: 22)
                ))
                .frame(height: 36)
            }
            .padding(14, 12, 10, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .boxDecoration(
                color: AppColors.surface,
                radius: 14,
                borderColor: AppColors.border,
                shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: Offset(0, 4))]
            )
        }

        // ── Amount Summary Card (collapsible) ─────────────────────────────────

        @ViewBuilder
        private func buildAmountSummaryCard(
            baseTotal: Double,
            grandTotal: Double,
            booking: FlightBookingState,
            memberPoints: Int,
            rewardValue: Double,
            signedIn: Bool
        ) -> some View {
            let subTotal = Int(baseTotal.rounded())
            let adults = booking.travellerCount
            let promoActive = state.appliedCode != nil
            let displayGrandTotal = grandTotal

            VStack(alignment: .leading, spacing: 0) {
                // ── Header (always visible) ──────────────────────────────────
                HStack(spacing: 0) {
                    Text(LocaleKeys.booking_amount_summary.tr())
                        .textStyle(AppTypography.body(15, weight: .w700, color: AppColors.textPrimary))
                    Spacer(minLength: 0)
                    Text(Formatters.price(displayGrandTotal))
                        .textStyle(AppTypography.heading(15, color: AppColors.primary))
                    HGap(6)
                    Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: AppColors.primary)
                        .rotationEffect(.degrees(state.showAmountCard ? 180 : 0))
                        .animation(.linear(duration: 0.2), value: state.showAmountCard)
                }
                .padding(16, 14, 14, 14)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(PaymentPage.easeOutCubic(0.22)) { state.showAmountCard.toggle() }
                }

                // ── Collapsible body ─────────────────────────────────────────
                // AnimatedSize: the card grows/shrinks while its clip reveals
                // or hides the body, which itself switches instantly.
                if state.showAmountCard {
                    VStack(alignment: .leading, spacing: 0) {
                        Group {
                            MaterialDivider(height: 1, color: AppColors.dividerLight)
                            VGap(14)
                            // Promo code + Epic Member Point inputs now live
                            // inside the card — between the "Amount Summary"
                            // heading and the fare rows — with a dotted
                            // separator beneath them.
                            buildDiscountInputs(baseTotal: baseTotal, memberPoints: memberPoints, signedIn: signedIn)
                            VGap(14)
                            DottedLine()
                            VGap(14)
                        }
                        Group {
                            AmountRow(
                                label: LocaleKeys.booking_adult_s.tr(args: ["\(adults)"]),
                                value: Formatters.price(Double(subTotal))
                            )
                            VGap(12)
                            AmountRow(label: LocaleKeys.booking_sub_total.tr(), value: Formatters.price(Double(subTotal)))
                            VGap(12)
                            AmountRow(label: LocaleKeys.booking_discount.tr(), value: Formatters.price(0))
                            VGap(12)
                        }
                        if promoActive { buildPromoAppliedSection(baseTotal: baseTotal) }
                        // Reward points sits directly under Promotion so every
                        // deduction reads as one group above the separator.
                        if state.pointsApplied {
                            if promoActive { VGap(8) }
                            HStack(spacing: 0) {
                                Text(LocaleKeys.booking_reward_points_pts.tr(args: [Formatters.grouped(state.selectedPoints)]))
                                    .textStyle(AppTypography.body(13, weight: .w500, color: AppColors.textSecondary))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("- \(Formatters.price(rewardValue))")
                                    .textStyle(AppTypography.body(13, weight: .w600, color: AppColors.error))
                            }
                        }
                        DottedLine()
                            .padding(.vertical, 14)
                        HStack(spacing: 0) {
                            Text(LocaleKeys.common_grand_total.tr())
                                .textStyle(AppTypography.body(14, weight: .w700, color: AppColors.textPrimary))
                            Spacer(minLength: 0)
                            if promoActive {
                                Text(Formatters.price(baseTotal))
                                    .textStyle(
                                        AppTypography.body(13, color: AppColors.textPrimary)
                                            .copyWith(decoration: .lineThrough, decorationColor: AppColors.textPrimary)
                                    )
                                HGap(8)
                            }
                            Text(Formatters.price(displayGrandTotal))
                                .textStyle(AppTypography.body(14, weight: .w700, color: AppColors.textPrimary))
                        }
                    }
                    .padding(16, 0, 16, 16)
                    .transition(.identity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .boxDecoration(
                color: AppColors.surface,
                radius: 18,
                shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 20, offset: Offset(0, 6))]
            )
        }

        // ── Promo code + reward points (inside the Amount Summary card) ───────

        /// The two discount inputs the traveller fills in before paying.
        private func buildDiscountInputs(baseTotal: Double, memberPoints: Int, signedIn: Bool) -> some View {
            VStack(alignment: .leading, spacing: 0) {
                Text(LocaleKeys.booking_promo_code.tr())
                    .textStyle(AppTypography.body(13, weight: .w700, color: AppColors.textPrimary))
                VGap(8)
                buildPromoRow(baseTotal: baseTotal)
                if signedIn {
                    VGap(16)
                    buildRewardPointsSection(memberPoints: memberPoints)
                }
            }
        }

        private func buildPromoRow(baseTotal: Double) -> some View {
            HStack(spacing: 0) {
                TextField(
                    "",
                    text: Binding(get: { state.promoText }, set: { state.promoText = $0 }),
                    prompt: Text(LocaleKeys.booking_e_g_epic10.tr())
                        .font(AppTypography.body(13).font)
                        .foregroundColor(AppColors.textTertiary)
                )
                .font(AppTypography.body(13, weight: .w600).font)
                .foregroundStyle(AppColors.textPrimary)
                .tint(AppColors.primary)
                .textInputAutocapitalization(.characters)
                .onChange(of: state.promoText) { _, value in state.onPromoChanged(value) }
                .padding(14, 12, 14, 12)
                .boxDecoration(color: AppColors.surface, radius: 12, borderColor: AppColors.border)
                .frame(maxWidth: .infinity)
                HGap(10)
                Button {
                    Task { await state.applyPromo(baseTotal) }
                } label: {
                    if state.applyingPromo {
                        ProgressSpinner(size: 16, color: AppColors.primary)
                    } else {
                        Text(LocaleKeys.booking_apply.tr())
                            .textStyle(AppTypography.body(13, weight: .w700, color: AppColors.primary))
                    }
                }
                .buttonStyle(OutlinedButtonStyle(
                    foregroundColor: AppColors.primary,
                    borderColor: AppColors.border,
                    backgroundColor: AppColors.surface,
                    minimumHeight: 45,
                    fullWidth: false,
                    cornerRadius: 12,
                    padding: EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                ))
                .disabled(state.applyingPromo)
                // MaterialTapTargetSize.padded lays the 45pt button out at 48.
                .padding(.vertical, 1.5)
            }
        }

        private func buildPromoAppliedSection(baseTotal: Double) -> some View {
            let promoDiscount = state.discount
            let promo = state.appliedPromo
            let promoLabel = promo?.kind.lowercased() == "percent"
                ? "\(promo!.value)% off"
                : "Applied"

            return VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Text(LocaleKeys.booking_promo.tr())
                        .textStyle(AppTypography.body(13, weight: .w500, color: AppColors.textSecondary))
                    Spacer(minLength: 0)
                    HStack(spacing: 0) {
                        Text(promoLabel)
                            .textStyle(AppTypography.body(11, weight: .w700, color: AppColors.accent))
                        HGap(6)
                        Icon(Icons.close_rounded, size: 13, color: AppColors.accent)
                            .contentShape(Rectangle())
                            .onTapGesture { state.removePromo() }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .boxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        radius: 20,
                        borderColor: AppColors.accent.withValues(alpha: 0.45)
                    )
                }
                VGap(12)
                DottedLine()
                VGap(12)
                AmountRow(label: LocaleKeys.booking_total.tr(), value: Formatters.price(baseTotal))
                VGap(8)
                HStack(spacing: 0) {
                    Text(LocaleKeys.booking_promotion.tr())
                        .textStyle(AppTypography.body(13, weight: .w500, color: AppColors.textSecondary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("- \(Formatters.price(promoDiscount))")
                        .textStyle(AppTypography.body(13, weight: .w600, color: AppColors.error))
                }
            }
        }

        // ── Epic Member Point selector ────────────────────────────────────────

        /// Loyalty-point redemption field: a dropdown that reveals the member's
        /// balance, a "Use" action that redeems it, and — once redeemed — the
        /// MMK value of the points with a "Remove" affordance.
        private func buildRewardPointsSection(memberPoints: Int) -> some View {
            let selectedPoints = state.pointsApplied ? state.selectedPoints : memberPoints
            let pointsLabel = PaymentScreenState.pointsLabel(selectedPoints)

            return VStack(alignment: .leading, spacing: 0) {
                Text(LocaleKeys.booking_epic_member_point.tr())
                    .textStyle(AppTypography.body(13, weight: .w700, color: AppColors.textPrimary))
                VGap(8)
                HStack(spacing: 0) {
                    Text(state.pointsApplied ? pointsLabel : "Select reward points")
                        .textStyle(AppTypography.body(
                            13,
                            weight: state.pointsApplied ? .w700 : .w500,
                            color: state.pointsApplied ? AppColors.textPrimary : AppColors.textTertiary
                        ))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: state.pointsExpanded ? AppColors.primary : AppColors.textSecondary
                    )
                    .rotationEffect(.degrees(state.pointsExpanded ? 180 : 0))
                    .animation(.linear(duration: 0.2), value: state.pointsExpanded)
                }
                .padding(14, 12, 12, 12)
                .boxDecoration(
                    color: AppColors.surface,
                    radius: 12,
                    borderColor: state.pointsExpanded ? AppColors.primary : AppColors.border
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(PaymentPage.easeOutCubic(0.2)) { state.pointsExpanded.toggle() }
                }

                // Redeemed state: point → MMK conversion on the left, Remove on
                // the right.
                if state.pointsApplied {
                    VGap(6)
                    HStack(spacing: 0) {
                        Text(LocaleKeys.booking_mmk.tr(args: [pointsLabel]))
                            .textStyle(AppTypography.body(11, weight: .w500, color: AppColors.textPrimary))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(LocaleKeys.booking_remove.tr())
                            .textStyle(AppTypography.body(11, weight: .w600, color: AppColors.textPrimary))
                            .contentShape(Rectangle())
                            .onTapGesture { state.removePoints() }
                    }
                }

                // Dropdown panel with the member card row.
                if state.pointsExpanded {
                    buildRewardPointsDropdown(
                        memberPoints: memberPoints,
                        pointsLabel: PaymentScreenState.pointsLabel(memberPoints)
                    )
                    .transition(.identity)
                }
            }
        }

        private func buildRewardPointsDropdown(memberPoints: Int, pointsLabel: String) -> some View {
            let tier = tierForPoints(memberPoints)

            return VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Text(LocaleKeys.booking_epic_member.tr())
                        .textStyle(AppTypography.body(11, weight: .w700, color: AppColors.textSecondary, letterSpacing: 0.6))
                    HGap(8)
                    Text(tier.label)
                        .textStyle(AppTypography.body(11, weight: .w700, color: Colors.white))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .boxDecoration(color: AppColors.accent, radius: 20)
                }
                VGap(12)
                // Separates the tier heading from the redeemable balance below.
                MaterialDivider(height: 1, thickness: 1, color: AppColors.dividerLight)
                VGap(12)
                HStack(spacing: 0) {
                    Icon(Icons.star_rounded, size: 18, color: AppColors.accent)
                    HGap(6)
                    Text(pointsLabel)
                        .textStyle(AppTypography.body(14, weight: .w700, color: AppColors.textPrimary))
                    Spacer(minLength: 0)
                    Button {
                        state.usePoints(memberPoints)
                    } label: {
                        Text(LocaleKeys.booking_use.tr())
                            .textStyle(AppTypography.body(12, weight: .w700, color: Colors.white))
                    }
                    .buttonStyle(ElevatedButtonStyle(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumHeight: 34,
                        fullWidth: false,
                        cornerRadius: 8,
                        padding: EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18)
                    ))
                    .disabled(memberPoints <= 0)
                    // MaterialTapTargetSize.padded lays the 34pt button out at 48.
                    .padding(.vertical, 7)
                }
            }
            .padding(14, 12, 12, 12)
            .boxDecoration(
                color: AppColors.surface,
                radius: 12,
                borderColor: AppColors.dividerLight,
                shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 16, offset: Offset(0, 6))]
            )
            .padding(.top, 8)
        }

        // ── Payment method section ────────────────────────────────────────────

        private func buildPaymentSection() -> some View {
            let title: String
            let message: String
            if state.awaitingSmartPayReturn {
                if state.canResumeSmartPay {
                    title = "Your SmartPay payment is not completed"
                    message = "SmartPay is still waiting for payment. "
                        + "Tap Resume payment to reopen the "
                        + "secure checkout for this booking."
                } else {
                    title = "Waiting for your SmartPay payment"
                    message = "Come back to Epic World once you have "
                        + "paid and your e-ticket is issued "
                        + "automatically."
                }
            } else {
                title = "Pay securely with SmartPay"
                message = "Tapping Pay Now opens SmartPay in your browser, "
                    + "where you can pay by MMQR wallet or card. "
                    + "Return to Epic World afterwards to finish "
                    + "the booking."
            }

            return VStack(alignment: .leading, spacing: 0) {
                Text(LocaleKeys.booking_add_payment_method.tr())
                    .textStyle(AppTypography.heading(16))
                VGap(4)
                Text(LocaleKeys.booking_all_transactions_are_encrypted_and_secure.tr())
                    .textStyle(AppTypography.body(12, color: AppColors.textSecondary))
                VGap(16)
                // SmartPay's hosted checkout owns the method choice — MMQR
                // wallets, cards, everything — so the app no longer asks first.
                // Picking a wallet here and being asked again on the hosted page
                // would just be the same question twice.
                HStack(alignment: .top, spacing: 0) {
                    Icon(
                        state.awaitingSmartPayReturn ? Icons.hourglass_top_rounded : Icons.lock_rounded,
                        size: 20,
                        color: AppColors.primary
                    )
                    HGap(12)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(title)
                            .textStyle(AppTypography.body(13, weight: .w700))
                        VGap(4)
                        Text(message)
                            .textStyle(AppTypography.body(12, color: AppColors.textSecondary))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .boxDecoration(color: AppColors.background, radius: 14, borderColor: AppColors.dividerLight)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .boxDecoration(
                color: AppColors.surface,
                radius: 18,
                shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 20, offset: Offset(0, 6))]
            )
        }

        // ── Bottom bar ────────────────────────────────────────────────────────

        private func buildBottomBar(booking: FlightBookingState, total: Double) -> some View {
            let bottomInset = PaymentPage.safeAreaBottom
            return VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text(LocaleKeys.booking_total_amount.tr())
                        .textStyle(AppTypography.body(13, weight: .w600, color: AppColors.textSecondary))
                    Spacer(minLength: 0)
                    Text(Formatters.price(total))
                        .textStyle(AppTypography.heading(18, color: AppColors.primary))
                }
                .padding(.vertical, 6)
                VGap(10)
                // A spinner while a payment is being verified — the app does
                // that by itself on return, so there is nothing to tap. A
                // server-confirmed PENDING answer is the one exception: it has
                // not charged the customer, so reopening SmartPay is the right
                // recovery action.
                Button {
                    if state.canResumeSmartPay {
                        Task { await state.pay(booking, total) }
                    } else if state.awaitingSmartPayReturn {
                        state.retryVerification()
                    } else {
                        Task { await state.pay(booking, total) }
                    }
                } label: {
                    if state.verifying {
                        ProgressSpinner(size: 22, color: Colors.white)
                    } else {
                        Text(
                            state.canResumeSmartPay
                                ? "Resume payment"
                                : state.awaitingSmartPayReturn
                                ? "Confirm payment"
                                : LocaleKeys.booking_pay_now.tr()
                        )
                        .textStyle(AppTypography.body(16, weight: .w700, color: Colors.white))
                    }
                }
                .buttonStyle(ElevatedButtonStyle(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.35),
                    disabledForegroundColor: Colors.white,
                    cornerRadius: 14,
                    padding: EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0)
                ))
                .disabled(state.verifying)
            }
            // EdgeInsets.fromLTRB(16, 10, 16, bottomInset > 0 ? bottomInset - 8 : 2),
            // measured from the screen edge: the bar already sits above the
            // home indicator, so only the -8 overlap remains.
            .padding(EdgeInsets(top: 10, leading: 16, bottom: bottomInset > 0 ? -8 : 2, trailing: 16))
            .background(BottomBarBackground())
        }
    }
}

// MARK: - Payment success pop-up

extension PaymentPage {
    fileprivate struct PaymentSuccessDialog: View {
        let ticket: TicketModel
        let orderDate: String
        let customerName: String
        let paymentLabel: String
        let grandTotal: Double
        let onContinue: () -> Void

        var body: some View {
            VStack(spacing: 0) {
                Icon(Icons.check_rounded, size: 38, color: Colors.white)
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(AppColors.primary))
                VGap(20)
                Text(LocaleKeys.booking_success_e_ticket_is_registered.tr())
                    .textStyle(AppTypography.heading(19, color: AppColors.textPrimary))
                    .multilineTextAlignment(.center)
                VGap(8)
                Text(LocaleKeys.booking_please_check_email_for_confirmation_and.tr())
                    .textStyle(AppTypography.body(13, color: AppColors.textSecondary))
                    .multilineTextAlignment(.center)
                VGap(20)
                VStack(spacing: 0) {
                    SuccessRow(label: LocaleKeys.common_pnr_number.tr(), value: ticket.bookingReference)
                    VGap(10)
                    SuccessRow(label: LocaleKeys.common_booking_date.tr(), value: orderDate)
                    VGap(10)
                    SuccessRow(label: LocaleKeys.booking_contact_name.tr(), value: customerName)
                    VGap(10)
                    SuccessRow(label: LocaleKeys.booking_payment.tr(), value: paymentLabel)
                    VGap(10)
                    SuccessRow(
                        label: LocaleKeys.booking_total_amount.tr(),
                        value: Formatters.price(grandTotal),
                        valueColor: AppColors.primary
                    )
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .boxDecoration(color: AppColors.background, radius: 14)
                VGap(22)
                Button(action: onContinue) {
                    Text(LocaleKeys.booking_continue.tr())
                        .textStyle(AppTypography.body(15, weight: .w700, color: Colors.white))
                }
                .buttonStyle(ElevatedButtonStyle(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    cornerRadius: 30,
                    padding: EdgeInsets(top: 15, leading: 0, bottom: 15, trailing: 0)
                ))
            }
            .padding(24, 32, 24, 24)
            .frame(maxWidth: .infinity)
            .boxDecoration(color: AppColors.surface, radius: 24)
            // Dialog(insetPadding: horizontal 28) inside the modal host's 40pt
            // dialog inset.
            .padding(.horizontal, -12)
        }
    }

    fileprivate struct SuccessRow: View {
        let label: String
        let value: String
        var valueColor: Color? = nil

        var body: some View {
            HStack(alignment: .top, spacing: 0) {
                Text(label)
                    .textStyle(AppTypography.body(12.5, color: AppColors.textSecondary))
                HGap(12)
                Text(value)
                    .textStyle(AppTypography.body(12.5, weight: .w700, color: valueColor ?? AppColors.textPrimary))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

// MARK: - Shared pieces

extension PaymentPage {
    // ── Dotted separator ──────────────────────────────────────────────────────

    fileprivate struct DottedLine: View {
        var body: some View {
            GeometryReader { geometry in
                let dash: CGFloat = 3
                let gap: CGFloat = 6
                let count = max(0, Int((geometry.size.width / (dash + gap)).rounded(.down)))
                // MainAxisAlignment.spaceBetween.
                HStack(spacing: 0) {
                    ForEach(0..<count, id: \.self) { index in
                        if index > 0 { Spacer(minLength: 0) }
                        RoundedRectangle(cornerRadius: 1, style: .circular)
                            .fill(AppColors.border)
                            .frame(width: dash, height: 1.5)
                    }
                }
            }
            .frame(height: 1.5)
        }
    }

    // ── Amount row ────────────────────────────────────────────────────────────

    fileprivate struct AmountRow: View {
        let label: String
        let value: String

        var body: some View {
            HStack(spacing: 0) {
                Text(label)
                    .textStyle(AppTypography.body(13, weight: .w500, color: AppColors.textSecondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                HGap(12)
                Text(value)
                    .textStyle(AppTypography.body(13, weight: .w500, color: AppColors.textPrimary))
            }
        }
    }

    /// The bottom bar's white surface with its upward shadow
    /// (`BoxShadow(black 12%, blur 16, offset (0, -4))`), running under the
    /// home indicator like Flutter's `bottomNavigationBar`.
    fileprivate struct BottomBarBackground: View {
        var body: some View {
            ZStack {
                Rectangle()
                    .fill(Colors.black.withValues(alpha: 0.12))
                    .offset(x: 0, y: -4)
                    .blur(radius: 16 * 0.57735 + 0.5)
                Rectangle()
                    .fill(AppColors.surface)
            }
            .allowsHitTesting(false)
            .ignoresSafeArea(edges: .bottom)
        }
    }

    /// Flutter's `CircularProgressIndicator` at a fixed size.
    fileprivate struct ProgressSpinner: View {
        let size: CGFloat
        let color: Color

        var body: some View {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(color)
                .scaleEffect(size / 20)
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Retained checkout components (unreferenced, see the file header)

extension PaymentPage {
    /// A MMQR wallet the user can pay with (shown in the "Select your payment
    /// method" grid; its logo is embedded in the centre of the scan-to-pay QR).
    fileprivate struct WalletOption {
        let label: String
        let asset: String

        init(_ label: String, _ asset: String) {
            self.label = label
            self.asset = asset
        }
    }

    fileprivate static let wallets: [WalletOption] = [
        WalletOption("AYA Pay", AppAssets.bankAya),
        WalletOption("KBZPay", AppAssets.bankKbz),
        WalletOption("CB Pay", AppAssets.bankCb),
        WalletOption("WavePay", AppAssets.wave),
    ]

    // ── Payment method tile ───────────────────────────────────────────────────

    fileprivate struct PayMethodTile<Leading: View>: View {
        @ViewBuilder let leading: () -> Leading
        let title: String
        let subtitle: String
        let selected: Bool
        let onTap: () -> Void

        var body: some View {
            HStack(spacing: 0) {
                leading()
                HGap(12)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).textStyle(AppTypography.body(15, weight: .w700))
                    VGap(2)
                    Text(subtitle).textStyle(AppTypography.body(12, color: AppColors.textSecondary))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ZStack {
                    Circle()
                        .strokeBorder(selected ? AppColors.primary : AppColors.border, lineWidth: 2)
                    if selected {
                        Circle()
                            .fill(AppColors.primary)
                            .frame(width: 10, height: 10)
                    }
                }
                .frame(width: 22, height: 22)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .boxDecoration(
                color: AppColors.surface,
                radius: 14,
                // Selected border uses primary green, unselected uses light gray
                borderColor: selected ? AppColors.primary : AppColors.border,
                borderWidth: selected ? 1.5 : 1
            )
            .animation(.linear(duration: 0.18), value: selected)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
        }
    }

    // ── MMQR logo (tile icon) ─────────────────────────────────────────────────

    fileprivate struct MmqrLogo: View {
        var size: CGFloat = 46

        var body: some View {
            AppImage(AppAssets.mmqr, width: size, height: size, fit: .cover)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .circular))
        }
    }

    // ── Visa logo (tile icon) ─────────────────────────────────────────────────

    fileprivate struct VisaLogo: View {
        var body: some View {
            AppImage(AppAssets.visaHero, fit: .contain)
                .padding(4)
                .frame(width: 46, height: 46)
                .boxDecoration(color: AppColors.surface, radius: 10)
        }
    }

    // ── MMQR wallet card (grid item) ──────────────────────────────────────────

    fileprivate struct WalletCard: View {
        let wallet: WalletOption
        let selected: Bool
        let onTap: () -> Void

        var body: some View {
            VStack(spacing: 0) {
                AppImage(wallet.asset, width: 38, height: 38, fit: .cover)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .circular))
                VGap(8)
                Text(wallet.label)
                    .textStyle(AppTypography.body(11, weight: .w600, color: AppColors.textPrimary))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .boxDecoration(
                color: selected ? AppColors.primary.withValues(alpha: 0.06) : AppColors.surface,
                radius: 14,
                borderColor: selected ? AppColors.primary : AppColors.border,
                borderWidth: selected ? 1.5 : 1
            )
            .animation(.linear(duration: 0.16), value: selected)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
        }
    }

    // ── MMQR scan-to-pay pop-up ───────────────────────────────────────────────

    /// The "Scan to pay" dialog: a MyanmarPay MMQR card with the chosen
    /// wallet's logo embedded in the centre of the QR. Simulates the payment by
    /// "waiting" for 5 seconds, then pops `true` so the caller can issue the
    /// ticket.
    fileprivate struct MmqrScanDialog: View {
        let amount: Double
        let wallet: WalletOption
        let accountName: String

        @Environment(\.dismissModal) private var dismissModal

        init(amount: Double, wallet: WalletOption, accountName: String) {
            self.amount = amount
            self.wallet = wallet
            self.accountName = accountName
        }

        var body: some View {
            ScrollView {
                VStack(spacing: 0) {
                    // Header: title + close.
                    HStack(spacing: 0) {
                        Text(LocaleKeys.booking_scan_to_pay.tr())
                            .textStyle(AppTypography.heading(18))
                        Spacer(minLength: 0)
                        Icon(Icons.close_rounded, size: 22, color: AppColors.textTertiary)
                            .contentShape(Rectangle())
                            .onTapGesture { dismissModal(false) }
                    }
                    VGap(16)
                    qrCard()
                    VGap(16)
                    // Save QR (mock action).
                    Button {
                        SnackBarCenter.shared.show(LocaleKeys.booking_qr_code_saved.tr(), floating: true)
                    } label: {
                        HStack(spacing: 0) {
                            Icon(Icons.download_rounded, size: 18, color: AppColors.textPrimary)
                            HGap(8)
                            Text(LocaleKeys.booking_save_qr.tr())
                                .textStyle(AppTypography.body(13, weight: .w700))
                        }
                    }
                    .buttonStyle(OutlinedButtonStyle(
                        foregroundColor: AppColors.textPrimary,
                        borderColor: AppColors.border,
                        minimumHeight: 0,
                        fullWidth: false,
                        cornerRadius: 12,
                        padding: EdgeInsets(top: 12, leading: 22, bottom: 12, trailing: 22)
                    ))
                    VGap(14)
                    // Waiting-for-payment pill with a live spinner.
                    HStack(spacing: 0) {
                        ProgressSpinner(size: 16, color: AppColors.primary)
                        HGap(10)
                        Text(LocaleKeys.booking_waiting_for_payment.tr())
                            .textStyle(AppTypography.body(13, weight: .w600, color: AppColors.primary))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .frame(maxWidth: .infinity)
                    .boxDecoration(color: AppColors.primary.withValues(alpha: 0.08), radius: 12)
                }
                .padding(20, 18, 20, 20)
                .boxDecoration(color: AppColors.surface, radius: 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            // Dialog(insetPadding: 24 all round) inside the modal host's inset.
            .padding(.horizontal, -16)
            .task {
                // "Waiting for payment…" holds for 5s, then the payment lands.
                try? await Task.sleep(for: .seconds(5))
                if !Task.isCancelled { dismissModal(true) }
            }
        }

        // The scan-to-pay card is the real MMQR1.png artwork. Only the amount
        // and the QR's centre logo are overlaid on top so they reflect the live
        // payment; everything else (header, name, MMQR label, QR, footer) is
        // the photo.
        private func qrCard() -> some View {
            // MMQR1.png is 338×472 — all overlay coordinates are scaled from that.
            let nativeW: CGFloat = 338
            let nativeH: CGFloat = 472
            return GeometryReader { geometry in
                let w = geometry.size.width
                let scale = w / nativeW
                let s = { (v: CGFloat) -> CGFloat in v * scale }
                ZStack(alignment: .topLeading) {
                    AppImage(AppAssets.mmqrCode, width: w, height: nativeH * scale, fit: .fill)
                    // Account name + amount — one white patch fully covers the
                    // baked-in "SYSTEMATiC" and "1,000 MMK", then both are
                    // redrawn left-aligned from live data.
                    VStack(alignment: .leading, spacing: 0) {
                        Text(accountName)
                            .textStyle(AppTypography.body(s(12.5), weight: .w600, color: Color(0xFF3A3A3A), letterSpacing: 0.2))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        VGap(s(4))
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text(NumberFormat("#,###").format(amount))
                                .textStyle(AppTypography.heading(s(23), color: Color(0xFF111111)))
                            HGap(s(6))
                            Text(LocaleKeys.booking_mmk_2.tr())
                                .textStyle(AppTypography.body(s(11), weight: .w600, color: Color(0xFF9A9A9A)))
                        }
                    }
                    .padding(.top, s(3))
                    .frame(width: s(282), height: s(60), alignment: .leading)
                    .background(Colors.white)
                    .offset(x: s(28), y: s(96))
                    // Chosen wallet logo over the centre of the QR.
                    AppImage(wallet.asset, fit: .cover)
                        .clipShape(RoundedRectangle(cornerRadius: s(4), style: .circular))
                        .padding(s(3))
                        .frame(width: s(42), height: s(42))
                        .boxDecoration(color: Colors.white, radius: s(6))
                        .offset(x: s(167.5 - 21), y: s(312 - 21))
                }
                .frame(width: w, height: nativeH * scale, alignment: .topLeading)
                .boxDecoration(
                    color: Colors.white,
                    radius: 16,
                    shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 22, offset: Offset(0, 10))]
                )
            }
            .aspectRatio(nativeW / nativeH, contentMode: .fit)
        }
    }

    // ── Credit card form fields ───────────────────────────────────────────────

    fileprivate struct CreditCardFields: View {
        private static let border = Color(0xFFD9DCE1)

        @State private var cardNumber = ""
        @State private var expiry = ""
        @State private var cvv = ""
        @State private var holder = ""

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                LabelView("Card Number")
                VGap(7)
                field($cardNumber, hint: "1234  5678  9012  3456", keyboard: .numberPad) {
                    Icon(Icons.credit_card, size: 18, color: AppColors.textTertiary)
                }
                VGap(14)
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        LabelView("Expiry Date")
                        VGap(7)
                        field($expiry, hint: "MM / YY", keyboard: .numbersAndPunctuation) { EmptyView() }
                    }
                    .frame(maxWidth: .infinity)
                    HGap(12)
                    VStack(alignment: .leading, spacing: 0) {
                        LabelView("CVV")
                        VGap(7)
                        field($cvv, hint: "• • •", keyboard: .numberPad, secure: true) { EmptyView() }
                    }
                    .frame(maxWidth: .infinity)
                }
                VGap(14)
                LabelView("Cardholder Name")
                VGap(7)
                field($holder, hint: "Full name on card", keyboard: .namePhonePad) { EmptyView() }
            }
        }

        private func field<Suffix: View>(
            _ text: Binding<String>,
            hint: String,
            keyboard: UIKeyboardType,
            secure: Bool = false,
            @ViewBuilder suffix: () -> Suffix
        ) -> some View {
            HStack(spacing: 0) {
                Group {
                    if secure {
                        SecureField("", text: text, prompt: Text(hint).font(AppTypography.body(13).font).foregroundColor(AppColors.textTertiary))
                    } else {
                        TextField("", text: text, prompt: Text(hint).font(AppTypography.body(13).font).foregroundColor(AppColors.textTertiary))
                    }
                }
                .font(AppTypography.body(13.5, weight: .w500).font)
                .foregroundStyle(AppColors.textPrimary)
                .tint(AppColors.primary)
                .keyboardType(keyboard)
                .frame(maxWidth: .infinity)
                suffix()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .boxDecoration(color: AppColors.surface, radius: 12, borderColor: CreditCardFields.border)
        }
    }

    fileprivate struct LabelView: View {
        let text: String

        init(_ text: String) {
            self.text = text
        }

        var body: some View {
            Text(text)
                .textStyle(AppTypography.body(12, weight: .w600, color: AppColors.textSecondary))
        }
    }

    // ── Wallet gateway: confirmation sheet ────────────────────────────────────

    /// The sheet the wallet gateway slides up from the bottom after "Pay Now":
    /// payee, amount, a read-back of the order amount and the funding source.
    fileprivate struct GatewayConfirmSheet: View {
        let amount: Double

        @Environment(\.dismissModal) private var dismissModal

        init(amount: Double) {
            self.amount = amount
        }

        var body: some View {
            let amountText = PaymentPage.kGatewayAmount.format(amount)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Icon(Icons.close, size: 24, color: Colors.black87)
                        .padding(4)
                        .contentShape(Rectangle())
                        .onTapGesture { dismissModal(false) }
                    Spacer(minLength: 0)
                    Text(LocaleKeys.booking_use_pin.tr())
                        .textStyle(AppTypography.body(16, weight: .w500, color: PaymentPage.kGatewayAccent))
                }
                VGap(20)
                Text(LocaleKeys.booking_pay_for.tr(args: [PaymentPage.kGatewayMerchant]))
                    .textStyle(AppTypography.body(16, color: Colors.black87))
                VGap(10)
                GatewayAmountLine(amountText: amountText, size: 34)
                VGap(28)
                GatewayRowCard(label: LocaleKeys.booking_original_amount.tr()) {
                    Text("\(amountText) Ks")
                        .textStyle(AppTypography.body(15, weight: .w500, color: Colors.black87))
                }
                VGap(10)
                GatewayRowCard(label: LocaleKeys.booking_payment_method.tr()) {
                    HStack(spacing: 0) {
                        Icon(Icons.account_balance_wallet_rounded, size: 20, color: PaymentPage.kGatewayAccent)
                        HGap(8)
                        Text(LocaleKeys.booking_balance.tr())
                            .textStyle(AppTypography.body(15, weight: .w500, color: Colors.black87))
                    }
                }
                VGap(26)
                Button {
                    dismissModal(true)
                } label: {
                    Text(LocaleKeys.booking_confirm_payment.tr())
                        .textStyle(AppTypography.body(18, weight: .w500, color: Colors.white))
                }
                .buttonStyle(ElevatedButtonStyle(
                    backgroundColor: PaymentPage.kGatewayAccent,
                    foregroundColor: Colors.white,
                    cornerRadius: 8,
                    padding: EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0)
                ))
            }
            .padding(EdgeInsets(top: 14, leading: 20, bottom: 20, trailing: 20))
            .frame(maxWidth: .infinity)
            .background(
                UnevenRoundedRectangle(cornerRadii: BorderRadius.vertical(top: 22), style: .circular)
                    .fill(PaymentPage.kGatewaySurface)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }

    /// "94,650.00 Ks" with the currency riding along the amount's baseline.
    fileprivate struct GatewayAmountLine: View {
        let amountText: String
        let size: CGFloat

        var body: some View {
            HStack(alignment: .bottom, spacing: 0) {
                Text(amountText)
                    .textStyle(AppTypography.body(size, weight: .w500, color: Colors.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.1)
                HGap(6)
                Text("Ks")
                    .textStyle(AppTypography.body(size * 0.42, color: Colors.black87))
                    .padding(.bottom, size * 0.16)
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// White label/value card used by the gateway sheet.
    fileprivate struct GatewayRowCard<Trailing: View>: View {
        let label: String
        @ViewBuilder let trailing: () -> Trailing

        var body: some View {
            HStack(spacing: 0) {
                Text(label)
                    .textStyle(AppTypography.body(15, color: Color(0xFF8A8A8E)))
                    .frame(maxWidth: .infinity, alignment: .leading)
                trailing()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .boxDecoration(color: Colors.white, radius: 12)
        }
    }

    // ── Wallet gateway: PIN pad ───────────────────────────────────────────────

    /// Six-digit PIN step shown after "Confirm Payment". Any PIN is accepted
    /// (this is a mock gateway); it resolves true once six digits are entered.
    fileprivate struct GatewayPinDialog: View {
        private static let pinLength = 6

        let amount: Double

        @Environment(\.dismissModal) private var dismissModal
        @State private var pin = ""
        @State private var submitting = false

        init(amount: Double) {
            self.amount = amount
        }

        private func onDigit(_ digit: String) {
            if submitting || pin.count >= GatewayPinDialog.pinLength { return }
            pin += digit
            if pin.count == GatewayPinDialog.pinLength {
                Task { await submit() }
            }
        }

        private func onBackspace() {
            if submitting || pin.isEmpty { return }
            pin = String(pin.dropLast())
        }

        private func submit() async {
            submitting = true
            try? await Task.sleep(for: .milliseconds(400))
            dismissModal(true)
        }

        var body: some View {
            let amountText = PaymentPage.kGatewayAmount.format(amount)
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    ZStack {
                        HStack(spacing: 0) {
                            Icon(Icons.close, size: 24, color: Colors.black87)
                                .padding(2)
                                .contentShape(Rectangle())
                                .onTapGesture { dismissModal(false) }
                            Spacer(minLength: 0)
                        }
                        Text(LocaleKeys.booking_enter_pin.tr())
                            .textStyle(AppTypography.body(17, weight: .w500, color: Colors.black87))
                    }
                    .frame(height: 30)
                    VGap(22)
                    Text(LocaleKeys.booking_pay_for.tr(args: [PaymentPage.kGatewayMerchant]))
                        .textStyle(AppTypography.body(16, color: Colors.black87))
                    VGap(12)
                    GatewayAmountLine(amountText: amountText, size: 32)
                    VGap(26)
                    HStack(spacing: 0) {
                        ForEach(0..<GatewayPinDialog.pinLength, id: \.self) { index in
                            if index > 0 { Spacer(minLength: 0) }
                            ZStack {
                                if index < pin.count {
                                    Circle()
                                        .fill(Colors.black87)
                                        .frame(width: 12, height: 12)
                                }
                            }
                            .frame(width: 46, height: 52)
                            .boxDecoration(color: Color(0xFFF1F1F3), radius: 6)
                        }
                    }
                }
                .padding(20, 16, 20, 28)
                .frame(maxWidth: .infinity)
                .boxDecoration(color: Colors.white, radius: 16)
                .padding(14, 14, 14, 0)
                Spacer(minLength: 0)
                GatewayKeypad(onDigit: onDigit, onBackspace: onBackspace, enabled: !submitting)
            }
        }
    }

    /// Numeric keypad drawn in-app so the PIN never touches the system keyboard.
    fileprivate struct GatewayKeypad: View {
        let onDigit: (String) -> Void
        let onBackspace: () -> Void
        let enabled: Bool

        private static let grid = Color(0xFFC9CDD4)
        private static let dim = Color(0xFFD5D8DE)

        @ViewBuilder
        private func key<Content: View>(
            color: Color = Colors.white,
            onTap: (() -> Void)? = nil,
            @ViewBuilder content: () -> Content
        ) -> some View {
            Button {
                onTap?()
            } label: {
                content()
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(color)
            }
            .buttonStyle(.ink)
            .disabled(!enabled || onTap == nil)
            .padding(0.4)
            .frame(maxWidth: .infinity)
        }

        private func digit(_ d: String) -> some View {
            key(onTap: { onDigit(d) }) {
                Text(d).textStyle(AppTypography.body(26, color: Colors.black87))
            }
        }

        var body: some View {
            VStack(spacing: 0) {
                HStack(spacing: 0) { digit("1"); digit("2"); digit("3") }
                HStack(spacing: 0) { digit("4"); digit("5"); digit("6") }
                HStack(spacing: 0) { digit("7"); digit("8"); digit("9") }
                HStack(spacing: 0) {
                    key(color: GatewayKeypad.dim) { EmptyView() }
                    digit("0")
                    key(color: GatewayKeypad.dim, onTap: onBackspace) {
                        Icon(Icons.backspace_outlined, size: 24, color: Colors.black87)
                    }
                }
            }
            // Sits flush on the screen edge; the home-indicator strip keeps the
            // keypad's own background so nothing shows through underneath.
            .background(GatewayKeypad.grid.ignoresSafeArea(edges: .bottom))
        }
    }
}
