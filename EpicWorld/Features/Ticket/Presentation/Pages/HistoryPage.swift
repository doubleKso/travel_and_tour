// Port of lib/features/ticket/presentation/pages/history_page.dart
import SwiftUI
import UIKit

/// Customer booking history, populated by `dcExec:GetMyBookings`.
struct HistoryPage: View {
    let onBack: (() -> Void)?

    init(onBack: (() -> Void)? = nil) {
        self.onBack = onBack
    }

    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router

    /// The search field's text (Dart's `TextEditingController`).
    @State private var searchText = ""
    @State private var query = ""
    /// `initState`'s post-frame callback runs once.
    @State private var didInitialRefresh = false

    private func filtered(_ bookings: [BookingHistoryItem]) -> [BookingHistoryItem] {
        let query = self.query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty { return bookings }
        return bookings.filter { booking in
            [booking.route, booking.reference, booking.pnr, booking.contactFullName]
                .contains { $0.lowercased().contains(query) }
        }
    }

    private func filteredEnquiries(_ enquiries: [ServiceEnquiryModel]) -> [ServiceEnquiryModel] {
        let query = self.query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty { return enquiries }
        return enquiries.filter { enquiry in
            [enquiry.refName, enquiry.id, enquiry.name, enquiry.email, enquiry.status]
                .contains { $0.lowercased().contains(query) }
        }
    }

    /// Reload the device's saved guest references from the server and keep the
    /// indicator visible until their current status has been merged into the
    /// local cards.
    ///
    /// `deviceGuestBookings` normally absorbs a refresh failure and returns the
    /// stored list. Dart wraps this in a final `catch` so `RefreshIndicator`
    /// never sees an unhandled error; `AsyncResource.refresh()` never throws —
    /// a failure stays in the resource and the already-rendered device history
    /// is kept.
    private func refreshGuestBookings() async {
        _ = await container.deviceGuestBookings.refresh()
    }

    private func refreshSignedInHistory() async {
        // Future.wait: both history APIs refresh together; each keeps any error
        // in its own state while the pull gesture completes cleanly.
        let history = container.myBookingHistory
        let enquiries = container.myServiceEnquiries
        async let historyDone = history.refresh()
        async let enquiriesDone = enquiries.refresh()
        _ = await (historyDone, enquiriesDone)
    }

    /// History for a customer who never signed in.
    ///
    /// `GetMyBookings` has nothing to say without an account, so what the guest
    /// sees is what this device remembers of their own checkouts — refreshed
    /// against `listGuestBookings` — plus the way in for a booking made
    /// somewhere else.
    private var guestBody: some View {
        // A customer with just one (or no) booking can still pull down to check
        // its live status (a SwiftUI ScrollView always bounces).
        ScrollView {
            VStack(spacing: 0) {
                DeviceBookingsSection(
                    onFindByReference: { router.push(.findMyBooking) },
                    emptyAction: AnyView(findMyBookingButton)
                )
                .frame(maxWidth: .infinity)
                VGap(16)
                HistoryWrapLayout(alignCenter: true, crossAxisCenter: true) {
                    Text("Have an account? ")
                        .textStyle(AppTypography.body(12.5, color: AppColors.textSecondary))
                    Button {
                        router.push(.login())
                    } label: {
                        Text("Sign in")
                            .textStyle(AppTypography.body(12.5, weight: .w700, color: AppColors.primary))
                    }
                    .buttonStyle(.plain)
                    Text(" to see all your bookings in one place.")
                        .textStyle(AppTypography.body(12.5, color: AppColors.textSecondary))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(AppSpacing.screenH, 18, AppSpacing.screenH, 28)
        }
        .refreshable { await refreshGuestBookings() }
    }

    private var findMyBookingButton: some View {
        Button {
            router.push(.findMyBooking)
        } label: {
            HStack(spacing: 0) {
                Icon(Icons.search_rounded, size: 19)
                HGap(8)
                Text("Find my booking")
                    .textStyle(AppTypography.body(14, weight: .w700, color: Colors.white))
            }
        }
        .buttonStyle(ElevatedButtonStyle(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumHeight: 46,
            cornerRadius: 10,
            padding: EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        ))
        .frame(height: 46)
    }

    var body: some View {
        let signedIn = container.authNotifier.state.isAuthenticated
        let history = container.myBookingHistory.state
        let bookings = filtered(history.valueOrNull ?? [])
        let serviceEnquiries = container.myServiceEnquiries.state
        let enquiries = filteredEnquiries(serviceEnquiries.valueOrNull ?? [])

        Scaffold(
            backgroundColor: AppColors.surface,
            appBar: {
                AppBar(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    centerTitle: true,
                    titleStyle: AppTypography.heading(20, color: Colors.white),
                    leading: {
                        Button {
                            if let onBack { onBack() } else { Task { await router.maybePop() } }
                        } label: {
                            Icon(Icons.arrow_back, size: 24, color: Colors.white)
                                .frame(width: 48, height: 48)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 4)
                    },
                    actions: { EmptyView() },
                    title: { Text(LocaleKeys.ticket_travel_history.tr()) }
                )
            }
        ) {
            if !signedIn {
                guestBody
            } else {
                VStack(spacing: 0) {
                    SearchBox(text: $searchText, onChanged: { value in query = value })
                        .padding(AppSpacing.screenH, 12, AppSpacing.screenH, 4)
                    // Both history APIs refresh together. Each resource keeps
                    // any error while the pull gesture completes cleanly.
                    signedInContent(
                        history: history,
                        serviceEnquiries: serviceEnquiries,
                        bookings: bookings,
                        enquiries: enquiries
                    )
                    .frame(maxHeight: .infinity)
                    .refreshable { await refreshSignedInHistory() }
                }
            }
        }
        .task {
            guard !didInitialRefresh else { return }
            didInitialRefresh = true
            container.myBookingHistory.invalidate()
            container.myServiceEnquiries.invalidate()
        }
    }

    @ViewBuilder
    private func signedInContent(
        history: AsyncValue<[BookingHistoryItem]>,
        serviceEnquiries: AsyncValue<[ServiceEnquiryModel]>,
        bookings: [BookingHistoryItem],
        enquiries: [ServiceEnquiryModel]
    ) -> some View {
        if history.isLoading && serviceEnquiries.isLoading {
            ScrollableHistoryState {
                FlightOrbitLoader(size: 132)
            }
        } else if history.hasError && serviceEnquiries.hasError {
            ScrollableHistoryState {
                HistoryMessage(
                    icon: Icons.cloud_off_rounded,
                    message: "Unable to load booking history.",
                    actionLabel: "Retry",
                    onAction: { Task { await refreshSignedInHistory() } }
                )
            }
        } else if bookings.isEmpty && enquiries.isEmpty {
            ScrollableHistoryState {
                HistoryMessage(
                    icon: query.isEmpty ? Icons.history : Icons.search_off_rounded,
                    message: query.isEmpty
                        ? "No bookings found yet."
                        : "No bookings match “\(query)”."
                )
            }
        } else {
            HistoryList(bookings: bookings, enquiries: enquiries)
        }
    }
}

/// Makes loading, error and empty history states pullable too; a refresh must
/// not disappear just because the server currently returned no rows.
private struct ScrollableHistoryState<Child: View>: View {
    @ViewBuilder let child: () -> Child

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                child()
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }
}

private struct SearchBox: View {
    @Binding var text: String
    let onChanged: (String) -> Void

    init(text: Binding<String>, onChanged: @escaping (String) -> Void) {
        _text = text
        self.onChanged = onChanged
    }

    @FocusState private var focused: Bool

    var body: some View {
        // The decoration sets only `border`; the theme's `enabledBorder` /
        // `focusedBorder` (10pt corners, 1.6pt green when focused) take
        // precedence over it in Flutter, so those are what is drawn.
        HStack(spacing: 0) {
            Icon(Icons.search_rounded, size: 24, color: AppColors.textSecondary)
                .frame(width: 48, height: 48)
            TextField(
                "",
                text: $text,
                prompt: Text("Search route, reference or PNR")
                    .styled(AppTypography.body(14, color: AppColors.textTertiary))
            )
            .font(AppTypography.body(14).font)
            .foregroundStyle(AppColors.textPrimary)
            .submitLabel(.search)
            .autocorrectionDisabled()
            .focused($focused)
            .padding(.vertical, 12)
            .onChange(of: text) { _, newValue in onChanged(newValue) }
            if !text.isEmpty {
                Button {
                    text = ""
                    onChanged("")
                } label: {
                    Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary)
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(minHeight: 48)
        .background(RoundedRectangle(cornerRadius: AppTheme.radiusSm).fill(AppColors.background))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusSm)
                .strokeBorder(focused ? AppColors.primary : AppColors.border, lineWidth: focused ? 1.6 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }
}

private struct HistoryMessage: View {
    let icon: IconData
    let message: String
    var actionLabel: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Icon(icon, size: 56, color: AppColors.textTertiary)
            VGap(12)
            Text(message)
                .textStyle(AppTypography.body(14, color: AppColors.textSecondary))
                .multilineTextAlignment(.center)
            if let actionLabel {
                VGap(12)
                Button {
                    onAction?()
                } label: {
                    Text(actionLabel)
                        .textStyle(AppTypography.body(14, weight: .w500, color: AppColors.primary))
                }
                .buttonStyle(TextButtonStyle())
            }
        }
        .padding(24)
    }
}

private struct HistoryList: View {
    let bookings: [BookingHistoryItem]
    let enquiries: [ServiceEnquiryModel]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !enquiries.isEmpty {
                    HistorySectionTitle(title: "Commercial flight reservations")
                    VGap(8)
                    ForEach(Array(enquiries.enumerated()), id: \.offset) { _, enquiry in
                        ServiceEnquiryTile(enquiry: enquiry)
                        VGap(12)
                    }
                }
                if !bookings.isEmpty {
                    if !enquiries.isEmpty { VGap(8) }
                    HistorySectionTitle(title: "Bookings")
                    VGap(8)
                    ForEach(Array(bookings.enumerated()), id: \.offset) { _, booking in
                        BookingHistoryTile(booking: booking)
                        VGap(12)
                    }
                }
            }
            .padding(AppSpacing.screenH, 8, AppSpacing.screenH, 20)
        }
    }
}

private struct HistorySectionTitle: View {
    let title: String
    let subtitle: String? = nil

    init(title: String) {
        self.title = title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .textStyle(AppTypography.body(12, weight: .w800, color: AppColors.textPrimary))
            if let subtitle {
                Text(subtitle)
                    .textStyle(AppTypography.body(11.5, color: AppColors.textPrimary))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ServiceEnquiryTile: View {
    let enquiry: ServiceEnquiryModel

    var body: some View {
        let createdAt = enquiry.createdAt?.toLocal()
        Button {
            showEnquiryDetails(enquiry)
        } label: {
            HStack(alignment: .top, spacing: 0) {
                Icon(Icons.flight_rounded, size: 25, color: AppColors.primary)
                    .frame(width: 52, height: 52)
                    .boxDecoration(color: AppColors.primarySurface, radius: 12)
                HGap(12)
                VStack(alignment: .leading, spacing: 0) {
                    Text(enquiry.refName.isEmpty ? "Commercial flight reservation" : enquiry.refName)
                        .textStyle(AppTypography.heading(16))
                        .lineLimit(2)
                        .truncationMode(.tail)
                    VGap(5)
                    HistoryWrapLayout(spacing: 7, crossAxisCenter: true) {
                        Text(createdAt.map { "Requested \(Formatters.fullDate($0))" } ?? "Request received")
                            .textStyle(AppTypography.body(11.5, color: AppColors.textPrimary))
                        StatusPill(
                            label: enquiry.status.isEmpty ? "Request sent" : enquiry.status,
                            color: AppColors.warning
                        )
                    }
                    VGap(8)
                    Text("Our office will contact you to confirm the seat and fare.")
                        .textStyle(AppTypography.body(12.5, color: AppColors.textSecondary))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HGap(8)
                Icon(Icons.chevron_right_rounded, size: 24, color: AppColors.textTertiary)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(AppColors.warning.withValues(alpha: 0.42), lineWidth: 1)
            )
        }
        .buttonStyle(.ink(radius: 16))
    }

    private func showEnquiryDetails(_ enquiry: ServiceEnquiryModel) {
        Task {
            let _: Void? = await showModalBottomSheet(
                isScrollControlled: true,
                backgroundColor: Colors.transparent
            ) { _ in
                ServiceEnquiryDetailSheet(enquiry: enquiry)
            }
        }
    }
}

/// Mirrors the booking-history flight sheet for commercial-flight requests.
/// Unlike a ticketed booking, an enquiry has no confirmed itinerary yet, so it
/// shows the flight requested and the contact details sent to the office.
private struct ServiceEnquiryDetailSheet: View {
    let enquiry: ServiceEnquiryModel

    var body: some View {
        let requestReference = enquiry.refId.isEmpty ? enquiry.id : enquiry.refId
        DraggableSheet(initialChildSize: 0.72, minChildSize: 0.5, maxChildSize: 0.94) {
            VStack(alignment: .leading, spacing: 0) {
                SheetHandle()
                VGap(18)
                Text(enquiry.refName.isEmpty ? "Commercial flight reservation" : enquiry.refName)
                    .textStyle(AppTypography.heading(20, color: AppColors.textPrimary))
                VGap(4)
                HStack(spacing: 0) {
                    Text(requestReference.isEmpty
                        ? "Commercial flight request"
                        : "Request reference: \(requestReference)")
                        .textStyle(AppTypography.body(13, color: AppColors.textSecondary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    StatusPill(
                        label: enquiry.status.isEmpty ? "Request sent" : enquiry.status,
                        color: AppColors.warning
                    )
                }
                VGap(18)
                DetailSection(title: "Flight request") {
                    VStack(spacing: 0) {
                        EnquiryDetailRow("Service", enquiry.service)
                        EnquiryDetailRow("Preferred travel date", formatDate(enquiry.preferredDate))
                        EnquiryDetailRow("Travellers", "\(enquiry.pax)")
                        if let message = enquiry.message?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !message.isEmpty {
                            EnquiryDetailRow("Message", message)
                        }
                    }
                }
                VGap(14)
                DetailSection(title: "Contact") {
                    VStack(spacing: 0) {
                        EnquiryDetailRow("Full name", enquiry.name)
                        EnquiryDetailRow("Phone number", enquiry.phone)
                        EnquiryDetailRow("Email", enquiry.email)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20, 10, 20, 28)
        }
    }

    private func formatDate(_ value: String) -> String {
        guard let date = DateTime.tryParse(value) else {
            return value.isEmpty ? "—" : value
        }
        return Formatters.fullDate(date)
    }
}

private struct EnquiryDetailRow: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(label)
                .textStyle(AppTypography.body(12.5, color: AppColors.textPrimary))
                .frame(maxWidth: .infinity, alignment: .leading)
            HGap(16)
            Text(value.isEmpty ? "—" : value)
                .textStyle(AppTypography.body(12.5, weight: .w600, color: AppColors.textPrimary))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.bottom, 8)
    }
}

private struct BookingHistoryTile: View {
    let booking: BookingHistoryItem

    init(booking: BookingHistoryItem) {
        self.booking = booking
    }

    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router

    @State private var resuming = false
    @State private var openingETicket = false

    var body: some View {
        let statusColor = booking.isHeld
            ? AppColors.accent
            : (booking.isConfirmed ? AppColors.success : AppColors.textSecondary)
        let createdAt = booking.createdAt

        // Material + InkWell around the card; the action buttons inside take
        // their own taps.
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Text(booking.route.isEmpty ? "Flight booking" : booking.route)
                    .textStyle(AppTypography.heading(16, color: AppColors.textPrimary))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                StatusPill(label: booking.status, color: statusColor)
            }
            VGap(7)
            Text(referenceLine)
                .textStyle(AppTypography.body(12, weight: .w700, color: AppColors.primaryDark))
            VGap(10)
            HStack(spacing: 0) {
                Icon(Icons.person_outline_rounded, size: 16, color: AppColors.textSecondary)
                HGap(5)
                Text("\(booking.passengerCount) \(booking.passengerCount == 1 ? "traveller" : "travellers") · \(booking.cabin)")
                    .textStyle(AppTypography.body(12, color: AppColors.textSecondary))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(Formatters.price(booking.total, booking.currency))
                    .textStyle(AppTypography.heading(15, color: AppColors.primary))
            }
            if let createdAt {
                VGap(7)
                Text("Booked \(Formatters.fullDate(createdAt.toLocal()))")
                    .textStyle(AppTypography.body(11, color: AppColors.textPrimary))
            }
            // An unpaid hold can be taken back to the payment screen. Only
            // held bookings offer it — anything already ticketed is done.
            if booking.isHeld {
                VGap(12)
                Button {
                    Task { await payNow() }
                } label: {
                    if resuming {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Colors.white)
                            .controlSize(.small)
                            .frame(width: 18, height: 18)
                    } else {
                        Text(LocaleKeys.booking_pay_now.tr())
                            .textStyle(AppTypography.body(13, weight: .w700, color: Colors.white))
                    }
                }
                .buttonStyle(ElevatedButtonStyle(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.6),
                    disabledForegroundColor: Colors.white,
                    minimumHeight: 40,
                    cornerRadius: 9
                ))
                .disabled(resuming)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
            }
            if booking.isConfirmed {
                VGap(12)
                Button {
                    Task { await viewETicket() }
                } label: {
                    HStack(spacing: 0) {
                        if openingETicket {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(AppColors.primary)
                                .controlSize(.small)
                                .frame(width: 18, height: 18)
                        } else {
                            Icon(Icons.qr_code_2_rounded, size: 18)
                        }
                        HGap(8)
                        Text(LocaleKeys.ticket_view_e_ticket.tr())
                            .textStyle(AppTypography.body(13, weight: .w700, color: AppColors.primary))
                    }
                }
                .buttonStyle(OutlinedButtonStyle(
                    foregroundColor: AppColors.primary,
                    borderColor: AppColors.primary,
                    minimumHeight: 40,
                    cornerRadius: 9,
                    padding: EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
                ))
                .disabled(openingETicket)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(AppColors.border, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture { showBookingDetails(booking) }
    }

    /// `[if reference, if 'PNR …'].join(' · ')`.
    private var referenceLine: String {
        var parts: [String] = []
        if !booking.reference.isEmpty { parts.append(booking.reference) }
        if !booking.pnr.isEmpty { parts.append("PNR \(booking.pnr)") }
        return parts.joined(separator: " · ")
    }

    /// Re-opens the payment screen for a booking that was held but never paid.
    ///
    /// The row on screen may be minutes old, so the booking is re-read by
    /// reference first: it is the server's word on the amount still owed and on
    /// whether the hold is even alive. Segments come along to rebuild the
    /// itinerary the payment screen shows.
    private func payNow() async {
        guard let user = container.authNotifier.state.user, !user.id.isEmpty, !user.email.isEmpty else {
            notify("Please sign in to continue this payment.")
            return
        }
        if booking.reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notify("This booking has no reference to pay against.")
            return
        }

        resuming = true
        // finally: never leave the button spinning.
        defer { if resuming { resuming = false } }
        let service = container.bookingHistoryRemoteService
        let auth = container.authNotifier
        let reference = booking.reference
        let userId = user.id
        let email = user.email
        do {
            let latest = try await auth.withValidAccessToken { token in
                try await service.getMyBookingByRef(
                    reference: reference,
                    userId: userId,
                    email: email,
                    accessToken: token
                )
            }
            if Task.isCancelled { return }
            guard let latest else {
                notify("This booking could not be found. Please refresh.")
                return
            }
            if !latest.isHeld {
                notify("This booking is no longer awaiting payment.")
                container.myBookingHistory.invalidate()
                return
            }

            // A failed segment lookup is not worth blocking payment for; the screen
            // falls back to the route on the booking record.
            var segments: [BookingHistorySegment] = []
            do {
                segments = try await auth.withValidAccessToken { token in
                    try await service.getMyBookingSegments(
                        bookingId: latest.id,
                        accessToken: token
                    )
                }
            } catch {
                segments = []
            }
            if Task.isCancelled { return }

            let resume = HeldBookingResume.from(latest, segments: segments)
            container.flightBookingBloc.add(.heldBookingResumed(
                from: resume.from,
                to: resume.to,
                departDate: resume.departDate,
                adults: resume.adults,
                children: resume.children,
                infants: resume.infants,
                cabinClass: resume.cabinClass,
                outbound: resume.outbound,
                inbound: resume.inbound,
                holdRequest: resume.holdRequest,
                holdResponse: resume.holdResponse,
                stage: .payment
            ))
            if Task.isCancelled { return }

            // The spinner covers the lookup above and nothing more.
            //
            // The payment screen never pops: it leaves by replacing the stack —
            // `.bookingCompleted` once paid, `.mainShell` when the customer
            // confirms "leave payment" — so the route this push returns may never
            // complete for *this* tile. The History tab stays alive underneath,
            // so awaiting it here left the button spinning for the rest of the
            // session on any booking the customer backed out of. The payment
            // screen owns the flow, and its own loading UI, from here.
            resuming = false
            router.push(.payment)
        } catch {
            if Task.isCancelled { return }
            notify(ApiException.messageFrom(error))
        }
    }

    private func viewETicket() async {
        if booking.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notify("This ticket is missing its booking ID. Please refresh.")
            return
        }

        openingETicket = true
        do {
            let detail = try await container.myBookingHistoryDetail(booking.id).future
            if !Task.isCancelled {
                await showETicketDialog(HistoryETicket.from(booking, detail))
            }
        } catch {
            if !Task.isCancelled { notify(ApiException.messageFrom(error)) }
        }
        openingETicket = false
    }

    private func notify(_ message: String) {
        SnackBarCenter.shared.show(message, floating: true)
    }

    private func showBookingDetails(_ booking: BookingHistoryItem) {
        Task {
            let _: Void? = await showModalBottomSheet(
                isScrollControlled: true,
                backgroundColor: Colors.transparent
            ) { _ in
                BookingHistoryDetailSheet(booking: booking)
            }
        }
    }
}

private struct StatusPill: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label.isEmpty ? "Booked" : label)
            .textStyle(AppTypography.body(10.5, weight: .w700, color: color))
            .padding(horizontal: 9, vertical: 4)
            .boxDecoration(color: color.withValues(alpha: 0.13), radius: 20)
    }
}

private struct BookingHistoryDetailSheet: View {
    let booking: BookingHistoryItem

    init(booking: BookingHistoryItem) {
        self.booking = booking
    }

    @Environment(AppContainer.self) private var container

    var body: some View {
        let detail = container.myBookingHistoryDetail(booking.id).state
        DraggableSheet(initialChildSize: 0.78, minChildSize: 0.5, maxChildSize: 0.94) {
            VStack(alignment: .leading, spacing: 0) {
                SheetHandle()
                VGap(18)
                Text(booking.reference.isEmpty ? "Booking details" : booking.reference)
                    .textStyle(AppTypography.heading(20, color: AppColors.textPrimary))
                VGap(4)
                Text(booking.pnr.isEmpty ? booking.route : "Airline PNR: \(booking.pnr)")
                    .textStyle(AppTypography.body(13, color: AppColors.textSecondary))
                VGap(18)
                detail.when(
                    data: { value in
                        AnyView(DetailBody(booking: booking, detail: value))
                    },
                    error: { _ in
                        AnyView(
                            Text("Unable to load flight and traveller details.")
                                .textStyle(AppTypography.body(14, color: AppColors.error))
                        )
                    },
                    loading: {
                        AnyView(
                            FlightOrbitLoader(size: 104)
                                .frame(maxWidth: .infinity)
                                .padding(24)
                        )
                    }
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20, 10, 20, 28)
        }
    }
}

private struct DetailBody: View {
    let booking: BookingHistoryItem
    let detail: BookingHistoryDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DetailSection(title: "Flights") {
                if detail.segments.isEmpty {
                    Text("No flight segments available.")
                        .textStyle(AppTypography.bodyMedium)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(detail.segments.enumerated()), id: \.offset) { _, segment in
                            SegmentRow(segment: segment)
                        }
                    }
                }
            }
            VGap(14)
            DetailSection(title: "Travellers") {
                if detail.passengers.isEmpty {
                    Text("No traveller details available.")
                        .textStyle(AppTypography.bodyMedium)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(detail.passengers.enumerated()), id: \.offset) { _, passenger in
                            Text("\(passenger.fullName) · \(passenger.type)")
                                .textStyle(AppTypography.body(13, color: AppColors.textPrimary))
                                .padding(.bottom, 8)
                        }
                    }
                }
            }
            VGap(14)
            DetailSection(title: "Contact") {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(booking.contactTitle) \(booking.contactFullName)".trimmingCharacters(in: .whitespacesAndNewlines))
                        .textStyle(AppTypography.body(13, color: AppColors.textPrimary))
                    VGap(5)
                    Text("\(booking.contactCountryCode) \(booking.contactPhone)")
                        .textStyle(AppTypography.body(13, color: AppColors.textSecondary))
                    VGap(5)
                    Text(booking.contactEmail)
                        .textStyle(AppTypography.body(13, color: AppColors.textSecondary))
                }
            }
        }
    }
}

private struct DetailSection<Child: View>: View {
    let title: String
    @ViewBuilder let child: () -> Child

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .textStyle(AppTypography.heading(15, color: AppColors.textPrimary))
            VGap(10)
            child()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .boxDecoration(color: AppColors.background, radius: 14, borderColor: AppColors.border)
    }
}

private struct SegmentRow: View {
    let segment: BookingHistorySegment

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(segment.fromCode) → \(segment.toCode)")
                .textStyle(AppTypography.body(14, weight: .w700, color: AppColors.textPrimary))
            VGap(3)
            Text("\(segment.travelDate) · \(segment.departTime) – \(segment.arriveTime)")
                .textStyle(AppTypography.body(12, color: AppColors.textSecondary))
            Text("\(segment.carrierName) · \(segment.flightNo)")
                .textStyle(AppTypography.body(12, color: AppColors.textSecondary))
        }
        .padding(.bottom, 10)
    }
}

// ── Sheet chrome ──────────────────────────────────────────────────────────────

/// The 42 × 4 grabber at the top of both detail sheets.
private struct SheetHandle: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 9)
            .fill(AppColors.border)
            .frame(width: 42, height: 4)
            .frame(maxWidth: .infinity)
    }
}

/// `DraggableScrollableSheet(initialChildSize:, minChildSize:, maxChildSize:)`
/// inside a transparent modal sheet: a surface with 24pt top corners whose
/// height is a fraction of the screen, scrolling its content. Dragging the
/// top strip resizes it between the min and max sizes; dragging it below the
/// minimum dismisses the sheet.
private struct DraggableSheet<Content: View>: View {
    let initialChildSize: CGFloat
    let minChildSize: CGFloat
    let maxChildSize: CGFloat
    let content: () -> Content

    init(
        initialChildSize: CGFloat,
        minChildSize: CGFloat,
        maxChildSize: CGFloat,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.initialChildSize = initialChildSize
        self.minChildSize = minChildSize
        self.maxChildSize = maxChildSize
        self.content = content
    }

    @Environment(\.dismissModal) private var dismissModal
    @State private var extent: CGFloat?
    @State private var dragStartExtent: CGFloat?

    private var screenHeight: CGFloat {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return scene?.screen.bounds.height ?? 800
    }

    var body: some View {
        let current = extent ?? initialChildSize
        ScrollView {
            content()
        }
        .frame(height: screenHeight * current)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(cornerRadii: BorderRadius.vertical(top: 24), style: .circular)
                .fill(AppColors.surface)
                .ignoresSafeArea(edges: .bottom)
        )
        .clipShape(UnevenRoundedRectangle(cornerRadii: BorderRadius.vertical(top: 24), style: .circular))
        .overlay(alignment: .top) {
            Color.clear
                .frame(height: 36)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let start = dragStartExtent ?? current
                            dragStartExtent = start
                            let proposed = start - value.translation.height / screenHeight
                            extent = min(max(proposed, minChildSize * 0.5), maxChildSize)
                        }
                        .onEnded { _ in
                            let settled = extent ?? initialChildSize
                            dragStartExtent = nil
                            if settled < minChildSize {
                                dismissModal()
                            } else {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    extent = min(max(settled, minChildSize), maxChildSize)
                                }
                            }
                        }
                )
        }
    }
}

// ── Wrap ──────────────────────────────────────────────────────────────────────

/// Flutter's `Wrap`, start- or centre-aligned runs.
private struct HistoryWrapLayout: Layout {
    var spacing: CGFloat = 0
    var runSpacing: CGFloat = 0
    /// `WrapAlignment.center`.
    var alignCenter = false
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
            if !current.indices.isEmpty && current.width + spacing + size.width > maxWidth {
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
        let measured = sizes(bounds.width, subviews)
        var y = bounds.minY
        for run in runs(bounds.width, measured) {
            var x = bounds.minX + (alignCenter ? (bounds.width - run.width) / 2 : 0)
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
