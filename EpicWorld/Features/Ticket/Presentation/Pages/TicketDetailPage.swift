// Port of lib/features/ticket/presentation/pages/ticket_detail_page.dart
import SwiftUI
import UIKit

/// TICKET DETAIL — everything about a single booked ticket, reached by tapping
/// a ticket in History or the active Tickets tab.
///
/// The page can get long, so the heavy detail (flight legs, passenger, amount)
/// lives in collapsible dropdown sections, and the boarding QR opens in a
/// pop-up rather than taking up permanent vertical space.
struct TicketDetailPage: View {
    let ticket: TicketModel

    init(ticket: TicketModel) {
        self.ticket = ticket
    }

    @Environment(AppRouter.self) private var router

    @State private var pdfBusy = false

    private var t: TicketModel { ticket }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 0) {
                        // Flight summary card, sitting above the detail sections.
                        summaryCard
                        VGap(16)
                        ExpandableCard(
                            icon: Icons.flight_takeoff_rounded,
                            title: LocaleKeys.ticket_flight_details.tr(),
                            initiallyExpanded: true
                        ) {
                            flightDetails
                        }
                        VGap(12)
                        ExpandableCard(
                            icon: Icons.person_outline_rounded,
                            title: LocaleKeys.ticket_passenger.tr()
                        ) {
                            passengerDetails
                        }
                        VGap(12)
                        ExpandableCard(
                            icon: Icons.receipt_long_rounded,
                            title: LocaleKeys.ticket_amount_details.tr()
                        ) {
                            amountDetails
                        }
                    }
                    .padding(AppSpacing.screenH, 16, AppSpacing.screenH, 24)
                }
                .frame(maxHeight: .infinity)
                bottomBar(bottomInset: proxy.safeAreaInsets.bottom)
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .background(AppColors.surface.ignoresSafeArea())
    }

    // ── Green header ──────────────────────────────────────────────────────────

    private var header: some View {
        HStack(spacing: 0) {
            Button {
                Task { await router.maybePop() }
            } label: {
                Icon(Icons.arrow_back, size: 24, color: Colors.white)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            Text(LocaleKeys.ticket_ticket_details.tr())
                .textStyle(AppTypography.heading(20, color: Colors.white))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            HGap(48)
        }
        .padding(4, 6, 4, 22)
        .frame(maxWidth: .infinity)
        .background(AppColors.primary.ignoresSafeArea(edges: .top))
    }

    // ── Summary card — shared Trip Summary design (pin timeline of both legs) ──

    private var summaryCard: some View {
        TripSummaryCard(outbound: t.outbound, inbound: t.inbound)
    }

    // ── Bottom action bar (View E-Ticket · Download PDF) ──────────────────────

    private func bottomBar(bottomInset: CGFloat) -> some View {
        HStack(spacing: 0) {
            Button {
                showETicket()
            } label: {
                HStack(spacing: 0) {
                    Icon(Icons.qr_code_2_rounded, size: 18, color: AppColors.primary)
                    HGap(8)
                    Text(LocaleKeys.ticket_view_e_ticket.tr())
                        .textStyle(AppTypography.body(13, weight: .w700, color: AppColors.primary))
                }
            }
            .buttonStyle(OutlinedButtonStyle(
                borderColor: AppColors.primary,
                cornerRadius: 12,
                padding: EdgeInsets(top: 13, leading: 0, bottom: 13, trailing: 0)
            ))
            .frame(maxWidth: .infinity)
            HGap(12)
            Button {
                Task { await downloadPdf() }
            } label: {
                HStack(spacing: 0) {
                    if pdfBusy {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Colors.white)
                            .controlSize(.small)
                            .frame(width: 16, height: 16)
                    } else {
                        Icon(Icons.download_rounded, size: 18)
                    }
                    HGap(8)
                    Text(LocaleKeys.common_download_pdf.tr())
                        .textStyle(AppTypography.body(13, weight: .w700, color: Colors.white))
                }
            }
            .buttonStyle(ElevatedButtonStyle(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                cornerRadius: 12,
                padding: EdgeInsets(top: 13, leading: 0, bottom: 13, trailing: 0)
            ))
            .disabled(pdfBusy)
            .frame(maxWidth: .infinity)
        }
        .padding(16, 12, 16, bottomInset > 0 ? bottomInset - 8 : 12)
        .frame(maxWidth: .infinity)
        .background(
            Color.clear.boxDecoration(
                color: AppColors.surface,
                shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: Offset(0, -4))]
            )
        )
    }

    // ── Dropdown bodies ───────────────────────────────────────────────────────

    private var flightDetails: some View {
        VStack(spacing: 0) {
            legBlock(t.outbound, isReturn: false)
            if let inbound = t.inbound {
                VGap(14)
                MaterialDivider(height: 1, color: AppColors.dividerLight)
                VGap(14)
                legBlock(inbound, isReturn: true)
            }
        }
    }

    private func legBlock(_ leg: TripOptionModel, isReturn: Bool) -> some View {
        // Return flights are labelled in the warm accent (yellow); departures blue.
        let labelColor = isReturn ? AppColors.warning : AppColors.info
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Icon(isReturn ? Icons.flight_land : Icons.flight_takeoff, size: 15, color: labelColor)
                HGap(6)
                Text("\(isReturn ? "Return" : "Departing") flight")
                    .textStyle(AppTypography.body(12.5, weight: .w700, color: labelColor))
            }
            VGap(10)
            kv("Ticket No.", t.bookingReference)
            // Route kept on a single line — scales down to fit if it's long.
            kvWidget("Route") {
                Text("\(leg.originName) (\(leg.originCode)) → \(leg.destinationName) (\(leg.destinationCode))")
                    .textStyle(AppTypography.body(12.5, weight: .w600, color: AppColors.textPrimary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.1)
            }
            kv("Date", Formatters.fullDate(leg.departure))
            kv("Departure", Formatters.time12(leg.departure))
            kv("Arrival", Formatters.time12(leg.arrival))
            kv("Duration", Formatters.duration(leg.duration))
            kv("Stops", leg.isDirect ? "Non-stop" : "\(leg.stops) stop\(leg.stops > 1 ? "s" : "")")
            kvWidget("Cabin class") { ClassBadge(travelClass: leg.travelClass) }
            kv("Airline", leg.operatorName)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // One block per seat booked — each traveller with their own details.
    private static let namePool = [
        "Hein Htet Zaw",
        "Aung Kaung Myat",
        "Su Myat Noe",
        "Kyaw Zin Latt",
        "Ei Ei Phyo",
    ]

    private func passengerNames() -> [String] {
        var names = [t.passengerName]
        if t.seatCount > 1 {
            for i in 1..<t.seatCount {
                names.append(Self.namePool[i % Self.namePool.count])
            }
        }
        return names
    }

    private func passport(_ i: Int) -> String {
        let n = (abs(dartHashCode(t.bookingReference)) + i * 137) % 900000 + 100000
        return "MB\(n)"
    }

    private func seat(_ i: Int) -> String {
        let letter = UnicodeScalar(65 + i % 6).map { String(Character($0)) } ?? ""
        return "\(12 + i / 6)\(letter)"
    }

    private var passengerDetails: some View {
        let names = passengerNames()
        return VStack(spacing: 0) {
            ForEach(Array(names.enumerated()), id: \.offset) { i, name in
                if i > 0 {
                    VGap(12)
                    MaterialDivider(height: 1, color: AppColors.dividerLight)
                    VGap(12)
                }
                passengerBlock(i, name)
            }
        }
    }

    private func passengerBlock(_ i: Int, _ name: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Text("\(i + 1)")
                    .textStyle(AppTypography.body(12, weight: .w700, color: Colors.white))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(AppColors.accent))
                HGap(10)
                Text(name)
                    .textStyle(AppTypography.body(13.5, weight: .w700, color: AppColors.textPrimary))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(LocaleKeys.ticket_adult.tr())
                    .textStyle(AppTypography.body(10.5, weight: .w700, color: AppColors.primaryDark))
                    .padding(horizontal: 10, vertical: 4)
                    .boxDecoration(color: AppColors.primarySurface, radius: 20)
            }
            VGap(8)
            kv("Passport No.", passport(i))
            kv("Seat", seat(i))
            kv("Airline", t.outbound.operatorName)
            kv("Bags", "20 kg")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Fare breakdown mirroring the Payment page's Amount Summary card.
    private var amountDetails: some View {
        let grand = t.totalPaid
        let subTotal = (grand + t.discount).rounded()

        return VStack(spacing: 0) {
            amountRow("\(t.seatCount) × Adult(s)", Formatters.price(subTotal, t.currency))
            VGap(10)
            amountRow("Sub Total", Formatters.price(subTotal, t.currency))
            VGap(10)
            amountRow("Discount", Formatters.price(t.discount, t.currency), sign: "−")
            VGap(12)
            MaterialDivider(height: 1, color: AppColors.border)
            VGap(10)
            HStack(spacing: 0) {
                Text(LocaleKeys.common_grand_total.tr())
                    .textStyle(AppTypography.body(14, weight: .w700, color: AppColors.textPrimary))
                Spacer(minLength: 0)
                Text(Formatters.price(grand, t.currency))
                    .textStyle(AppTypography.heading(17, color: AppColors.primaryDark))
            }
        }
    }

    private func amountRow(_ label: String, _ value: String, sign: String = "") -> some View {
        HStack(spacing: 0) {
            Text(label)
                .textStyle(AppTypography.body(13, weight: .w500, color: AppColors.textSecondary))
                .frame(maxWidth: .infinity, alignment: .leading)
            HGap(12)
            Text(sign.isEmpty ? value : "\(sign) \(value)")
                .textStyle(AppTypography.body(13, weight: .w500, color: AppColors.textPrimary))
        }
    }

    private func kv(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(label)
                .textStyle(AppTypography.body(12.5, color: AppColors.textSecondary))
                .frame(width: 118, alignment: .leading)
            HGap(12)
            Text(value)
                .textStyle(AppTypography.body(12.5, weight: .w600, color: AppColors.textPrimary))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 5)
    }

    // Same label ↔ value row as `kv`, but with a widget (e.g. a badge) on the
    // right instead of plain text.
    private func kvWidget<Value: View>(_ label: String, @ViewBuilder _ value: () -> Value) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .textStyle(AppTypography.body(12.5, color: AppColors.textSecondary))
                .frame(width: 118, alignment: .leading)
            HGap(12)
            value()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 5)
    }

    // ── E-Ticket pop-up ───────────────────────────────────────────────────────

    // Shows the full Booking-Confirmed e-ticket in a scrollable pop-up.
    private func showETicket() {
        Task { await showETicketDialog(t) }
    }

    // ── Download PDF ──────────────────────────────────────────────────────────

    private func downloadPdf() async {
        pdfBusy = true
        do {
            // Drawn natively as a full-width A4 document (see `ETicketPdf.build`) so it
            // prints as proper A4 pages rather than one long mobile-shaped strip.
            let bytes = await ETicketPdf.build(t)
            let filename = ETicketPdf.fileName(t)

            // Dart's web branch (`kIsWeb` → savePdfToDevice) has no iOS counterpart.

            // Native share / save sheet; when the file cannot be handed to it,
            // fall back to the print / "Save as PDF" dialog (`Printing.layoutPdf`).
            if !SharePresenter.sharePdf(bytes, filename: filename) {
                try presentPrintDialog(bytes, name: filename)
            }
        } catch {
            SnackBarCenter.shared.show(
                LocaleKeys.common_could_not_download_pdf.tr(args: ["\(error)"]),
                backgroundColor: AppColors.error,
                floating: true
            )
        }
        pdfBusy = false
    }

    private func presentPrintDialog(_ bytes: Data, name: String) throws {
        guard UIPrintInteractionController.isPrintingAvailable else {
            throw Exception("Printing is not available on this device.")
        }
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.jobName = name
        info.outputType = .general
        controller.printInfo = info
        controller.printingItem = bytes
        _ = controller.present(animated: true)
    }
}

// ── Collapsible "dropdown" section ─────────────────────────────────────────────

private struct ExpandableCard<Content: View>: View {
    let icon: IconData
    let title: String
    let initiallyExpanded: Bool
    @ViewBuilder let content: () -> Content

    @State private var open: Bool

    init(
        icon: IconData,
        title: String,
        initiallyExpanded: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.initiallyExpanded = initiallyExpanded
        self.content = content
        _open = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                // AnimatedSize: 220 ms, easeOutCubic.
                withAnimation(.timingCurve(0.215, 0.61, 0.355, 1, duration: 0.22)) { open.toggle() }
            } label: {
                HStack(spacing: 0) {
                    Icon(icon, size: 18, color: AppColors.primary)
                    HGap(10)
                    Text(title)
                        .textStyle(AppTypography.body(14, weight: .w700, color: AppColors.textPrimary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    // AnimatedRotation: 200 ms, linear.
                    Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: AppColors.textSecondary)
                        .rotationEffect(.degrees(open ? 180 : 0))
                        .animation(.linear(duration: 0.2), value: open)
                }
                .padding(14, 14, 12, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // The child swaps at once and only the height animates, clipped to
            // the card (no fade), as AnimatedSize does.
            VStack(spacing: 0) {
                if open {
                    VStack(spacing: 0) {
                        MaterialDivider(height: 1, color: AppColors.dividerLight)
                        content()
                            .padding(14, 12, 14, 14)
                    }
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
        .boxDecoration(color: AppColors.surface, radius: 16, borderColor: AppColors.border)
    }
}

/// Dart VM `String.hashCode` (Jenkins one-at-a-time over UTF-16 code units,
/// 30-bit), so the mock passport numbers match the Flutter app's.
private func dartHashCode(_ value: String) -> Int {
    var hash: UInt32 = 0
    for unit in value.utf16 {
        hash = hash &+ UInt32(unit)
        hash = hash &+ (hash << 10)
        hash ^= hash >> 6
    }
    hash = hash &+ (hash << 3)
    hash ^= hash >> 11
    hash = hash &+ (hash << 15)
    hash &= (1 << 30) - 1
    return hash == 0 ? 1 : Int(hash)
}
