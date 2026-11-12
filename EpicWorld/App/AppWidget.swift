import SwiftUI
import GoogleSignIn

/// The root view: navigator, modal/snack-bar hosts, start-up, deep links and
/// notification taps — the port of lib/app/app_widget.dart.
///
/// Keep this thin. Screen logic lives in features; cross-cutting concerns
/// live in `Core/`.
struct AppWidget: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.scenePhase) private var scenePhase

    @State private var sessionRestored = false
    @State private var notificationNavigationScheduled = false
    @State private var notificationLoginPromptedFor: PushMessage?
    @State private var hasBecomeActive = false
    @State private var locale = LocaleStore.shared

    var body: some View {
        let router = container.router
        ZStack {
            NavigationStack(path: Binding(get: { router.path }, set: { router.setPath($0) })) {
                RouteView(entry: router.root)
                    .id(router.root.id)
                    .navigationDestination(for: AppRouter.Entry.self) { entry in
                        RouteView(entry: entry)
                    }
            }
            if let overlay = router.overlay {
                // auto_route CustomRoute(opaque: false, fadeIn 400ms / 250ms).
                RouteView(entry: overlay)
                    .transition(.opacity)
                    .zIndex(1)
            }
            ModalHost().zIndex(2)
            SnackBarHost().zIndex(3)
            FlavorBanner().zIndex(4)
        }
        .environment(router)
        .environment(\.locale, Locale(identifier: locale.code))
        .preferredColorScheme(.light)
        .tint(AppColors.primary)
        .task { await startUp() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            // Flutter only reports `resumed` after the app was away, never
            // for the first launch.
            if hasBecomeActive { onResumed() } else { hasBecomeActive = true }
        }
        .onOpenURL { url in handleLink(url) }
        .onChange(of: pendingOpenIdentity) { _, identity in
            if identity != nil { scheduleNotificationNavigation() }
        }
        .onChange(of: container.authNotifier.state.isAuthenticated) { _, authenticated in
            if authenticated { scheduleNotificationNavigation() }
        }
        // `_appRouter.addListener(_scheduleNotificationNavigation)`.
        .onChange(of: router.topEntryID) { scheduleNotificationNavigation() }
    }

    private var pendingOpenIdentity: ObjectIdentifier? {
        container.pushNotificationService.pendingOpen.map(ObjectIdentifier.init)
    }

    // MARK: - Start-up (initState + post-frame callback)

    private func startUp() async {
        prefetchReferenceData()
        Task { await startNotifications() }
        if container.authNotifier.state.isAuthenticated {
            await container.authNotifier.restoreSessionFromApi()
        }
        sessionRestored = true
        container.appReady.value = true
        // Preserve a routed entry such as SmartPay's return URL. The automatic
        // signed-in redirect is only for the ordinary welcome entry point.
        let router = container.router
        if container.authNotifier.state.isAuthenticated
            && (router.currentPath.isEmpty || router.currentPath == "/") {
            router.replaceAll([.mainShell])
        }
        scheduleNotificationNavigation()
    }

    /// Keep the flight reference catalogue and catalogue lists ready for the
    /// search form. Each resource also watches the auth token, so login/logout
    /// reloads them with the current session while guests stay supported.
    private func prefetchReferenceData() {
        container.locationList.startIfNeeded()
        container.activeCountryList.startIfNeeded()
        container.activeFlightCarrierList.startIfNeeded()
        container.activeFlightScheduleList.startIfNeeded()
        container.globalAirlineRateList.startIfNeeded()
        container.tierAirlineRateList.startIfNeeded()
        container.tourPackageList.startIfNeeded()
        container.hotelList.startIfNeeded()
        container.membershipTierList.startIfNeeded()
        container.memberTierBenefitList.startIfNeeded()
        container.memberGlobalAirlineRateList.startIfNeeded()
        container.memberTierAirlineRateList.startIfNeeded()
        container.activeVisaCountryList.startIfNeeded()
        container.publishedVisaTypeCountryList.startIfNeeded()
    }

    private func startNotifications() async {
        let service = container.pushNotificationService
        await service.initialize()
        await service.requestPermissionIfNeeded()
    }

    // MARK: - Notification taps

    private func scheduleNotificationNavigation() {
        guard sessionRestored, !notificationNavigationScheduled else { return }
        notificationNavigationScheduled = true
        DispatchQueue.main.async {
            notificationNavigationScheduled = false
            let service = container.pushNotificationService
            let router = container.router
            guard let pending = service.pendingOpen else { return }
            // Login may still be saving credentials after publishing its auth
            // state. Wait for its navigation to complete.
            if router.currentName == Route.loginName { return }
            if !container.authNotifier.state.isAuthenticated {
                // Retain the tap across login rather than opening an empty
                // guest inbox. If login is dismissed, let the customer go on.
                if notificationLoginPromptedFor === pending { return }
                notificationLoginPromptedFor = pending
                router.navigate(.login(popOnSuccess: true))
                return
            }
            let message = service.takePendingOpen()
            if let id = message?.notificationId {
                Task { await container.markNotificationRead(id) }
            }
            container.notificationRemoteList.invalidate()
            router.navigate(.notifications)
        }
    }

    // MARK: - Lifecycle

    /// Renews an access token that expired while the app was away — a wallet
    /// app opened from SmartPay's checkout, a phone left on the desk.
    private func onResumed() {
        let notifications = container.pushNotificationService
        Task {
            if notifications.isInitialized {
                await notifications.refreshPermission()
            } else {
                await notifications.initialize()
            }
        }
        // Includes messages received while backgrounded.
        container.notificationRemoteList.invalidate()
        guard container.authNotifier.state.isAuthenticated else { return }
        Task { _ = await container.authNotifier.ensureValidAccessToken() }
    }

    // MARK: - Links

    /// Decides what an incoming link does to the navigator.
    ///
    /// SmartPay's return URL is the only link Epic World claims:
    /// * **Warm return, payment screen alive** — navigate nowhere; bringing
    ///   the app forward is the whole job, and `PaymentPage`'s resume check
    ///   verifies the payment and issues the ticket.
    /// * **Anything else** — a cold start, or no checkout left on the stack:
    ///   land on `PaymentReturnPage`, which verifies against the backend.
    private func handleLink(_ url: URL) {
        if GIDSignIn.sharedInstance.handle(url) { return }
        guard PaymentReturnPage.isReturnUrl(url) else { return }
        let router = container.router
        let isInitial = !sessionRestored
        if !isInitial && router.currentName == Route.paymentName { return }
        router.replaceAll([.paymentReturn])
    }
}
