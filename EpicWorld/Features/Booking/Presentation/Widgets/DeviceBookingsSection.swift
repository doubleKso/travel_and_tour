// Port of lib/features/booking/presentation/widgets/device_bookings_section.dart
import SwiftUI

/// The bookings this device remembers from guest checkouts.
///
/// A guest has no account to look history up under, so this list is their only
/// way back to a reservation they have not paid for yet — hence "Pay now" on
/// every live hold, and the reminder that the list lives on this device alone.
///
/// `compact` draws the lighter version used above the "Find my booking" form,
/// where the section is a shortcut rather than the whole screen.
struct DeviceBookingsSection<EmptyAction: View>: View {
    let compact: Bool

    /// Shown under the list as "Booked somewhere else? Find it by reference".
    /// Omitted on the screen that link leads to.
    let onFindByReference: (() -> Void)?

    /// Offered when there is nothing stored and no form on screen to fall back
    /// to; ignored in `compact` mode, which simply disappears when empty.
    /// (Dart `Widget? emptyAction`; `EmptyView` means none.)
    let emptyAction: () -> EmptyAction

    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router
    @Environment(\.routeEntryID) private var entryID

    /// The reference currently being looked up, so only that card spins.
    @State private var opening: String?

    init(
        compact: Bool = false,
        onFindByReference: (() -> Void)? = nil,
        @ViewBuilder emptyAction: @escaping () -> EmptyAction
    ) {
        self.compact = compact
        self.onFindByReference = onFindByReference
        self.emptyAction = emptyAction
    }

    /// The same, with the empty-state action passed as a view value
    /// (`emptyAction: AnyView(button)`), as the Dart call sites pass a widget.
    init(
        compact: Bool = false,
        onFindByReference: (() -> Void)? = nil,
        emptyAction: EmptyAction
    ) {
        self.init(compact: compact, onFindByReference: onFindByReference, emptyAction: { emptyAction })
    }

    private var hasEmptyAction: Bool { EmptyAction.self != EmptyView.self }

    /// Dart `mounted`: the route this section is drawn on is still on the stack.
    private var mounted: Bool {
        guard let entryID else { return true }
        return router.entries.contains { $0.id == entryID }
    }

    private func open(_ record: GuestBookingRecord) async {
        if opening != nil { return }
        opening = record.reference
        let error = await openGuestBooking(
            container,
            router,
            reference: record.reference,
            email: record.email,
            isMounted: { mounted }
        )
        if !mounted { return }
        opening = nil
        if let error { notify(error) }
    }

    private func forget(_ record: GuestBookingRecord) async {
        await GuestBookingStore.remove(record.reference)
        if !mounted { return }
        container.deviceGuestBookings.invalidate()
    }

    /// Clearing the list loses the customer's only route back to an unpaid hold,
    /// so it asks first — with the same dialog the checkout uses.
    private func forgetAll() async {
        let confirmed: Bool? = await showDialog(
            barrierDismissible: false,
            // showCupertinoDialog's barrier (kCupertinoModalBarrierColor).
            barrierColor: Color(0x33000000)
        ) { _ in
            IosConfirmDialog(
                title: "Forget bookings on this device?",
                message: "The list is cleared from this device only. Your bookings are "
                    + "unaffected, and you can find them again by reference.",
                confirmLabel: LocaleKeys.common_yes.tr(),
                cancelLabel: LocaleKeys.common_no.tr()
            )
        }
        if confirmed != true { return }
        await GuestBookingStore.clear()
        if !mounted { return }
        container.deviceGuestBookings.invalidate()
    }

    private func notify(_ message: String) {
        SnackBarCenter.shared.show(message, floating: true)
    }

    var body: some View {
        let bookings = container.deviceGuestBookings.state
        let records: [GuestBookingRecord] = bookings.valueOrNull ?? []

        if records.isEmpty {
            if bookings.isLoading {
                FlightOrbitLoader(size: 104)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if compact {
                EmptyView()
            } else {
                empty()
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                header(records.count)
                VGap(12)
                ForEach(Array(records.enumerated()), id: \.offset) { _, record in
                    if compact {
                        GuestBookingRow(
                            record: record,
                            busy: opening == record.reference,
                            onOpen: { Task { await open(record) } },
                            onForget: { Task { await forget(record) } }
                        )
                    } else {
                        GuestBookingCard(
                            record: record,
                            busy: opening == record.reference,
                            onPay: { Task { await open(record) } },
                            onForget: { Task { await forget(record) } }
                        )
                    }
                    VGap(10)
                }
                VGap(2)
                Text("Saved on this device only. Clear them if this device is shared.")
                    .textStyle(AppTypography.body(11.5, color: AppColors.textPrimary))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                if onFindByReference != nil {
                    VGap(14)
                    findLink()
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private func header(_ count: Int) -> some View {
        if compact {
            HStack(spacing: 0) {
                Text("Your recent bookings")
                    .textStyle(AppTypography.body(13.5, weight: .w700, color: AppColors.textPrimary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                textAction("Forget all") { Task { await forgetAll() } }
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                    Text("My bookings")
                        .textStyle(AppTypography.heading(21))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    textAction("Forget all on this device") { Task { await forgetAll() } }
                }
                VGap(3)
                Text(count == 1
                    ? "The trip you have booked from this device."
                    : "The trips you have booked from this device.")
                    .textStyle(AppTypography.body(13, color: AppColors.textSecondary))
            }
        }
    }

    @ViewBuilder
    private func empty() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("My bookings")
                .textStyle(AppTypography.heading(21))
                .frame(maxWidth: .infinity, alignment: .leading)
            VGap(3)
            Text("Bookings you make without signing in are kept on this device so you "
                + "can pick them up again.")
                .textStyle(AppTypography.body(13, color: AppColors.textSecondary))
                .frame(maxWidth: .infinity, alignment: .leading)
            VGap(16)
            if hasEmptyAction {
                emptyAction()
                    .frame(maxWidth: .infinity)
            }
            if onFindByReference != nil {
                VGap(14)
                findLink()
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func findLink() -> some View {
        WrapLayout(alignment: .center) {
            Text("Booked somewhere else? ")
                .textStyle(AppTypography.body(12.5, color: AppColors.textSecondary))
            Text("Find it by reference")
                .textStyle(AppTypography.body(12.5, weight: .w700, color: AppColors.primary))
                .onTapGesture { onFindByReference?() }
        }
    }

    private func textAction(_ label: String, _ onTap: @escaping () -> Void) -> some View {
        Text(label)
            .textStyle(AppTypography.body(12, color: AppColors.textSecondary))
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
    }
}

extension DeviceBookingsSection where EmptyAction == EmptyView {
    init(compact: Bool = false, onFindByReference: (() -> Void)? = nil) {
        self.init(compact: compact, onFindByReference: onFindByReference, emptyAction: { EmptyView() })
    }
}

// MARK: - Logic shared by the cards (internal so the unit tests reach it)

extension DeviceBookingsSection {
    /// `EW-8F4PHA · Airline ref 17RJ5B · 6 Sep 2026`, skipping what is unknown.
    /// (Dart's top-level `_metaLine`.)
    static func metaLine(_ record: GuestBookingRecord) -> String {
        let travel = DateTime.tryParse(record.travelDate)
        var parts = [record.reference]
        if !record.pnr.isEmpty { parts.append("Airline ref \(record.pnr)") }
        if let travel { parts.append(Formatters.fullDate(travel)) }
        return parts.joined(separator: "  ·  ")
    }

    /// The countdown beside a live hold, e.g. `7h 44m left`.
    static func timeLeftLabel(_ left: Duration) -> String {
        "\(Formatters.countdown(left)) left"
    }

    /// The status chip's (background, foreground) — Dart's `_StatusChip`
    /// switch on the record's status.
    static func statusChipColors(_ record: GuestBookingRecord) -> (background: Color, foreground: Color) {
        if record.status == GuestBookingStatus.confirmed {
            return (AppColors.primarySurface, AppColors.primaryDark)
        }
        if record.status == GuestBookingStatus.cancelled {
            return (Color(0xFFFBE6E3), AppColors.error)
        }
        if record.isExpired {
            return (AppColors.divider, AppColors.textSecondary)
        }
        return (Color(0xFFFFEBC0), Color(0xFFA76B00))
    }
}

/// A held booking as a full history card: what it is, what is owed, how long
/// is left to pay, and the button that resumes it.
private struct GuestBookingCard: View {
    let record: GuestBookingRecord
    let busy: Bool
    let onPay: () -> Void
    let onForget: () -> Void

    var body: some View {
        if record.isPayable {
            // `Timer.periodic(30s)`: only a live hold has anything to count
            // down, and minute resolution is all the label shows.
            TimelineView(.periodic(from: Date(), by: 30)) { _ in
                card
            }
        } else {
            card
        }
    }

    @ViewBuilder
    private var card: some View {
        let left = record.timeLeft
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                ServiceAvatar()
                HGap(11)
                VStack(alignment: .leading, spacing: 0) {
                    WrapLayout(alignment: .leading, spacing: 8, runSpacing: 4) {
                        Text(record.route.isEmpty ? record.reference : record.route)
                            .textStyle(AppTypography.body(15, weight: .w700, color: AppColors.textPrimary))
                        StatusChip(record: record)
                        if record.isPayable, let left {
                            Text(DeviceBookingsSection<EmptyView>.timeLeftLabel(left))
                                .textStyle(AppTypography.body(11.5, weight: .w700, color: AppColors.accent))
                        }
                    }
                    VGap(5)
                    Text(DeviceBookingsSection<EmptyView>.metaLine(record))
                        .textStyle(AppTypography.body(11.5, color: AppColors.textSecondary))
                    VGap(3)
                    Text(record.maskedEmail)
                        .textStyle(AppTypography.body(11.5, color: AppColors.textPrimary))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HGap(8)
                VStack(alignment: .trailing, spacing: 0) {
                    // IconButton(visualDensity: compact): 40×40 tap target.
                    Button(action: onForget) {
                        Icon(Icons.close_rounded, size: 18, color: AppColors.textTertiary)
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Forget this booking")
                    VGap(2)
                    Text(Formatters.price(record.amount, record.currency))
                        .textStyle(AppTypography.heading(15, color: AppColors.primary))
                }
            }
            if record.isPayable {
                VGap(12)
                MaterialDivider(height: 1, color: AppColors.divider)
                VGap(12)
                // The theme's ElevatedButton minimum width is infinite, so the
                // button spans the card even inside `Align(centerLeft)`.
                Button(action: onPay) {
                    if busy {
                        ProgressSpinner(size: 17, color: Colors.white)
                    } else {
                        Text(LocaleKeys.booking_pay_now.tr())
                            .textStyle(AppTypography.body(13, weight: .w700, color: Colors.white))
                    }
                }
                .buttonStyle(ElevatedButtonStyle(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                    minimumHeight: 38,
                    cornerRadius: 9,
                    padding: EdgeInsets(top: 0, leading: 22, bottom: 0, trailing: 22)
                ))
                .frame(height: 38)
                .disabled(busy)
            }
        }
        .padding(14, 12, 8, 14)
        .boxDecoration(color: AppColors.surface, radius: 14, borderColor: AppColors.border)
    }
}

/// The same booking as one tappable line, for the "Find my booking" screen.
private struct GuestBookingRow: View {
    let record: GuestBookingRecord
    let busy: Bool
    let onOpen: () -> Void
    let onForget: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 0) {
                ServiceAvatar()
                HGap(11)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        Text(record.route.isEmpty ? record.reference : record.route)
                            .textStyle(AppTypography.body(14, weight: .w700, color: AppColors.textPrimary))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if !record.travelDate.isEmpty {
                            HGap(8)
                            Text(record.travelDate)
                                .textStyle(AppTypography.body(11.5, color: AppColors.textPrimary))
                        }
                    }
                    VGap(3)
                    Text("\(record.reference)  ·  \(record.maskedEmail)")
                        .textStyle(AppTypography.body(11.5, color: AppColors.textSecondary))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if busy {
                    ProgressSpinner(size: 16, color: AppColors.primary)
                        .padding(.horizontal, 8)
                } else {
                    // IconButton(visualDensity: compact): 40×40 tap target.
                    Button(action: onForget) {
                        Icon(Icons.close_rounded, size: 18, color: AppColors.textTertiary)
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Forget this booking")
                }
            }
            .padding(12, 10, 6, 10)
            .boxDecoration(color: AppColors.surface, radius: 12, borderColor: AppColors.border)
        }
        .buttonStyle(.ink(radius: 12))
        .disabled(busy)
    }
}

private struct ServiceAvatar: View {
    var body: some View {
        Icon(Icons.flight_takeoff_rounded, size: 18, color: AppColors.primary)
            .frame(width: 34, height: 34)
            .boxDecoration(color: AppColors.primarySurface, radius: 10)
    }
}

private struct StatusChip: View {
    let record: GuestBookingRecord

    var body: some View {
        let colors = DeviceBookingsSection<EmptyView>.statusChipColors(record)
        Text(GuestBookingStatus.label(record))
            .textStyle(AppTypography.body(10, weight: .w700, color: colors.foreground))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .boxDecoration(color: colors.background, radius: 9)
    }
}

/// Flutter's `CircularProgressIndicator` at a fixed size.
private struct ProgressSpinner: View {
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

/// Flutter's `Wrap(alignment:, spacing:, runSpacing:,
/// crossAxisAlignment: WrapCrossAlignment.center)`: children laid out in
/// runs, each run aligned horizontally, children centred within their run.
private struct WrapLayout: Layout {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = 0
    var runSpacing: CGFloat = 0

    private struct Run {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func computeRuns(maxWidth: CGFloat, subviews: Subviews) -> [Run] {
        var runs: [Run] = []
        var current = Run()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            let extra = current.indices.isEmpty ? size.width : spacing + size.width
            if !current.indices.isEmpty && current.width + extra > maxWidth {
                runs.append(current)
                current = Run()
            }
            current.width += current.indices.isEmpty ? size.width : spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { runs.append(current) }
        return runs
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let runs = computeRuns(maxWidth: maxWidth, subviews: subviews)
        let width = runs.map(\.width).max() ?? 0
        let height = runs.map(\.height).reduce(0, +) + runSpacing * CGFloat(max(runs.count - 1, 0))
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let runs = computeRuns(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for run in runs {
            var x: CGFloat
            switch alignment {
            case .center: x = bounds.minX + (bounds.width - run.width) / 2
            case .trailing: x = bounds.maxX - run.width
            default: x = bounds.minX
            }
            for index in run.indices {
                let proposalForChild = ProposedViewSize(width: bounds.width, height: nil)
                let size = subviews[index].sizeThatFits(proposalForChild)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (run.height - size.height) / 2),
                    anchor: .topLeading,
                    proposal: proposalForChild
                )
                x += size.width + spacing
            }
            y += run.height + runSpacing
        }
    }
}
