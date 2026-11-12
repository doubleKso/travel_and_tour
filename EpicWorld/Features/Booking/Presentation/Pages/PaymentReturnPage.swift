// Port of lib/features/booking/presentation/pages/payment_return_page.dart
import SwiftUI

/// Landing page for the backend's `SMARTPAY_RETURN_URL`.
///
/// A warm return to a live payment screen never lands here (`AppWidget`
/// leaves the navigator alone and `PaymentPage`'s resume check takes over), so
/// this page is what a cold start, or a return with no checkout left on the
/// stack, gets: the request identity is restored from
/// `PendingSmartPayPaymentStore`. Either way the backend stays the source of
/// truth — the URL's query parameters are never trusted as payment proof.
struct PaymentReturnPage: View {
    /// The route the backend's `SMARTPAY_RETURN_URL` points at
    /// (`https://epicworld-fad26.web.app/booking/payment/return`).
    ///
    /// Claimed as an iOS Universal Link, so a finished payment brings Epic
    /// World back to the front instead of stranding the customer in their
    /// browser.
    static let routePath = "/booking/payment/return"

    /// True when `url` is SmartPay handing the customer back to Epic World.
    ///
    /// Matched on the route, never on the host: the return URL points at
    /// whichever Epic World web origin the backend was configured with. The
    /// fragment is checked too, in case the web build is serving hash routes.
    /// What the query string claims about the payment is ignored — only
    /// `getPaymentStatus` settles that.
    static func isReturnUrl(_ url: URL) -> Bool {
        func matches(_ route: String) -> Bool {
            route == routePath || route.hasSuffix(routePath)
        }
        // Dart's `Uri.path` / `Uri.fragment` are the encoded forms and keep a
        // trailing slash, which `URL.path` would decode and drop.
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let path = (components?.percentEncodedPath ?? url.path).lowercased()
        let fragment = (components?.percentEncodedFragment ?? url.fragment ?? "").lowercased()
        return matches(path) || matches(fragment.components(separatedBy: "?").first ?? "")
    }

    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router
    @Environment(\.routeEntryID) private var entryID

    @State private var loading = true
    @State private var error: String?
    @State private var pending: PendingSmartPayPayment?
    @State private var status: GetPaymentStatusResponse?
    @State private var didInit = false

    init() {}

    /// Dart `mounted`: this route is still on the stack.
    private var mounted: Bool {
        guard let entryID else { return true }
        return router.entries.contains { $0.id == entryID }
    }

    private func checkStatus() async {
        guard let pending = PendingSmartPayPaymentStore.read() else {
            if !mounted { return }
            loading = false
            error = "No pending SmartPay payment was found on this device."
            return
        }

        loading = true
        error = nil
        self.pending = pending
        do {
            // A redirect back from SmartPay can land minutes after the session
            // token was minted, so renew it before asking the backend anything.
            let service = container.smartPayCallableService
            let status = try await container.authNotifier.withValidAccessToken { accessToken in
                try await service.getPaymentStatus(
                    GetPaymentStatusRequest(
                        reference: pending.reference,
                        accessToken: accessToken,
                        email: pending.email
                    )
                )
            }
            if status.isSuccessful || status.isTerminalFailure {
                await PendingSmartPayPaymentStore.clear()
            }
            // The redirect back from SmartPay is where a cold-started guest's
            // payment actually lands, so this — not the payment screen — is
            // what stops their device history from still offering to pay for it.
            if status.isSuccessful {
                await GuestBookingStore.updateStatus(pending.reference, GuestBookingStatus.confirmed)
            }
            if !mounted { return }
            self.status = status
            loading = false
            if status.isSuccessful { container.myBookingHistory.invalidate() }
        } catch {
            if !mounted { return }
            loading = false
            self.error = ApiException.messageFrom(error)
        }
    }

    private func continueToApp() {
        let signedIn = container.authNotifier.state.isAuthenticated
        container.mainShellTab.value = signedIn ? 2 : 0
        router.replaceAll([.mainShell])
    }

    var body: some View {
        let successful = status?.isSuccessful == true
        let failed = status?.isTerminalFailure == true
        let pendingStatus = status != nil && !successful && !failed

        let icon: IconData = successful
            ? Icons.check_circle_rounded
            : failed
            ? Icons.cancel_rounded
            : error != nil
            ? Icons.error_rounded
            : Icons.hourglass_top_rounded
        let color: Color = successful
            ? AppColors.primary
            : (failed || error != nil)
            ? AppColors.error
            : AppColors.accent
        let title = successful
            ? "Payment successful"
            : failed
            ? "Payment unsuccessful"
            : pendingStatus
            ? "Payment is processing"
            : error != nil
            ? "Unable to verify payment"
            : "Checking your payment"
        let message = successful
            ? "Your payment is verified and the booking has been ticketed."
            : status?.displayMessage
                ?? error
                ?? "Please wait while Epic World verifies the payment with SmartPay."
        let merchantOrderNo = status?.merchantOrderNo ?? pending?.merchantOrderNo ?? ""

        Scaffold(backgroundColor: AppColors.background) {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        if loading {
                            ProgressSpinner(size: 58, color: AppColors.primary)
                        } else {
                            Icon(icon, size: 68, color: color)
                        }
                        VGap(20)
                        Text(title)
                            .textStyle(AppTypography.heading(22))
                            .multilineTextAlignment(.center)
                        VGap(10)
                        Text(message)
                            .textStyle(AppTypography.body(14, color: AppColors.textSecondary))
                            .multilineTextAlignment(.center)
                        if let reference = pending?.reference, !reference.isEmpty {
                            VGap(18)
                            ReferenceRow(label: "Booking reference", value: reference)
                        }
                        if !merchantOrderNo.isEmpty {
                            VGap(8)
                            ReferenceRow(label: "SmartPay order", value: merchantOrderNo)
                        }
                        VGap(24)
                        if !loading && (pendingStatus || error != nil) {
                            Button {
                                Task { await checkStatus() }
                            } label: {
                                Text("Check again")
                                    .textStyle(AppTypography.body(16, weight: .w600, color: Colors.white))
                            }
                            .buttonStyle(ElevatedButtonStyle())
                            VGap(10)
                        }
                        if !loading {
                            if successful {
                                Button(action: continueToApp) {
                                    Text("Continue to Epic World")
                                        .textStyle(AppTypography.body(16, weight: .w600, color: Colors.white))
                                }
                                .buttonStyle(ElevatedButtonStyle())
                            } else {
                                Button(action: continueToApp) {
                                    Text("Back to Epic World")
                                        .textStyle(AppTypography.body(16, weight: .w600, color: AppColors.primary))
                                }
                                .buttonStyle(OutlinedButtonStyle())
                            }
                        }
                    }
                    .padding(28)
                    .frame(maxWidth: .infinity)
                    .boxDecoration(
                        color: AppColors.surface,
                        radius: 24,
                        shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 28, offset: Offset(0, 10))]
                    )
                    .frame(maxWidth: 440)
                    .padding(24)
                    // Center(SingleChildScrollView(...)): short content sits in
                    // the middle of the screen, long content scrolls.
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
            }
        }
        .onAppear {
            // `initState` → post-frame `_checkStatus()`, once.
            guard !didInit else { return }
            didInit = true
            Task { await checkStatus() }
        }
    }
}

private struct ReferenceRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .textStyle(AppTypography.body(12, color: AppColors.textSecondary))
                .frame(maxWidth: .infinity, alignment: .leading)
            HGap(12)
            Text(value)
                .textStyle(AppTypography.body(12, weight: .w700))
                .textSelection(.enabled)
        }
    }
}

/// Flutter's `CircularProgressIndicator` at a fixed size.
private struct ProgressSpinner: View {
    let size: CGFloat
    let color: Color

    var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .controlSize(.large)
            .tint(color)
            .scaleEffect(size / 37)
            .frame(width: size, height: size)
    }
}
