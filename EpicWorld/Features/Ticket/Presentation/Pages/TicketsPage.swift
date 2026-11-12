// Port of lib/features/ticket/presentation/pages/tickets_page.dart
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// TICKETS (Active) — upcoming trips with a live countdown reminder.
struct TicketsPage: View {
    let onBack: (() -> Void)?

    init(onBack: (() -> Void)? = nil) {
        self.onBack = onBack
    }

    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router

    /// Re-read once a minute so the countdown stays current (Dart's
    /// `Timer.periodic` + `setState`).
    @State private var now = DateTime.now()

    var body: some View {
        let tickets = container.ticketNotifier.state.active(now)

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
                    title: { Text(LocaleKeys.ticket_my_tickets.tr()) }
                )
            }
        ) {
            if let first = tickets.first {
                ScrollView {
                    VStack(spacing: 0) {
                        // Show the next upcoming ticket...
                        ActiveTicketCard(ticket: first, now: now)
                        VGap(16)
                        // ...with its details / QR in a tabbed card below.
                        TicketTabsCard(ticket: first)
                    }
                    .padding(AppSpacing.screenH)
                }
            } else {
                EmptyState(
                    icon: Icons.confirmation_number_outlined,
                    message: "No active tickets yet.\nBook a trip to see it here."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            // Refresh once a minute so the countdown stays current; cancelled
            // when the page goes away (Dart's `dispose`).
            while !Task.isCancelled {
                try? await Task.sleep(for: Duration(minutes: 1))
                if Task.isCancelled { break }
                now = DateTime.now()
            }
        }
        .task {
            // addPostFrameCallback: load once.
            if !container.ticketNotifier.state.loaded {
                await container.ticketNotifier.load()
            }
        }
    }
}

private struct ActiveTicketCard: View {
    let ticket: TicketModel
    let now: DateTime

    init(ticket: TicketModel, now: DateTime) {
        self.ticket = ticket
        self.now = now
    }

    @Environment(AppRouter.self) private var router

    var body: some View {
        let leg = ticket.outbound
        let remaining = ticket.timeUntilDeparture(now)

        Button {
            router.push(.ticketDetail(ticket: ticket))
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Text(ticket.bookingReference)
                        .textStyle(AppTypography.body(12, weight: .w600, color: Colors.white.withValues(alpha: 0.85)))
                    Spacer(minLength: 0)
                    Text(leg.operatorName)
                        .textStyle(AppTypography.body(11, weight: .w600, color: Colors.white))
                        .padding(horizontal: 10, vertical: 4)
                        .boxDecoration(color: Colors.white.withValues(alpha: 0.2), radius: 20)
                }
                VGap(16)
                HStack(spacing: 0) {
                    city(leg.originCode, Formatters.time(leg.departure))
                    Icon(Icons.flight, size: 22, color: Colors.white)
                        .frame(maxWidth: .infinity)
                    city(leg.destinationCode, Formatters.time(leg.arrival), end: true)
                }
                VGap(18)
                // Countdown reminder.
                HStack(spacing: 0) {
                    Icon(Icons.timer_outlined, size: 18, color: Colors.white)
                    HGap(8)
                    Text(LocaleKeys.ticket_departs_in.tr())
                        .textStyle(AppTypography.body(13, color: Colors.white))
                    Text(Formatters.countdown(remaining))
                        .textStyle(AppTypography.body(15, weight: .w700, color: Colors.white))
                    Spacer(minLength: 0)
                    Text(Formatters.shortDate(leg.departure))
                        .textStyle(AppTypography.body(12, color: Colors.white.withValues(alpha: 0.85)))
                }
                .padding(horizontal: 14, vertical: 12)
                .boxDecoration(color: Colors.white.withValues(alpha: 0.15), radius: 14)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .boxDecoration(
                color: AppColors.primary,
                radius: 20,
                shadows: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 16, offset: Offset(0, 8))]
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.bottom, 14)
    }

    private func city(_ code: String, _ time: String, end: Bool = false) -> some View {
        VStack(alignment: end ? .trailing : .leading, spacing: 0) {
            Text(code).textStyle(AppTypography.heading(24, color: Colors.white))
            Text(time).textStyle(AppTypography.body(13, color: Colors.white.withValues(alpha: 0.85)))
        }
    }
}

/// Card below the active ticket with two tabs: trip/customer **Detail** and a
/// scannable **QR** code.
private struct TicketTabsCard: View {
    let ticket: TicketModel

    init(ticket: TicketModel) {
        self.ticket = ticket
    }

    /// 0 = Detail, 1 = QR
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 0) {
            // ---- Tab switcher ----
            HStack(spacing: 0) {
                tabButton("Detail", Icons.receipt_long, 0)
                tabButton("QR Code", Icons.qr_code_2, 1)
            }
            .padding(4)
            .boxDecoration(color: AppColors.primarySurface, radius: 30)
            .padding(12)

            Group {
                if tab == 0 {
                    DetailView(ticket: ticket)
                } else {
                    QrView(ticket: ticket)
                }
            }
            .padding(18, 4, 18, 20)
        }
        .frame(maxWidth: .infinity)
        .boxDecoration(
            color: AppColors.surface,
            radius: 18,
            shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 20, offset: Offset(0, 8))]
        )
    }

    private func tabButton(_ label: String, _ icon: IconData, _ index: Int) -> some View {
        let selected = tab == index
        return Button {
            tab = index
        } label: {
            HStack(spacing: 0) {
                Icon(icon, size: 16, color: selected ? Colors.white : AppColors.primaryDark)
                HGap(6)
                Text(label)
                    .textStyle(AppTypography.body(13, weight: .w600, color: selected ? Colors.white : AppColors.primaryDark))
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(selected ? AppColors.primary : Colors.transparent)
            )
            // AnimatedContainer(duration: 200ms), linear.
            .animation(.linear(duration: 0.2), value: selected)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

/// Customer + trip detail grid (Detail tab).
private struct DetailView: View {
    let ticket: TicketModel

    var body: some View {
        let leg = ticket.outbound
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                info("Passenger", ticket.passengerName)
                info("Booking Ref", ticket.bookingReference)
            }
            VGap(16)
            HStack(spacing: 0) {
                info("Route", "\(leg.originCode) → \(leg.destinationCode)")
                info("Airline", leg.operatorName)
            }
            VGap(16)
            HStack(spacing: 0) {
                info("Date", Formatters.fullDate(leg.departure))
                info("Time", Formatters.time(leg.departure))
            }
            VGap(16)
            HStack(spacing: 0) {
                info("Class", leg.travelClass.label)
                info("Passengers", "\(ticket.seatCount) Adult\(ticket.seatCount > 1 ? "s" : "")")
            }
            VGap(16)
            HStack(spacing: 0) {
                info("Paid", Formatters.price(ticket.totalPaid, ticket.currency))
                info("Status", "Confirmed")
            }
        }
    }

    private func info(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).textStyle(AppTypography.body(11, color: AppColors.textPrimary))
            VGap(3)
            Text(value).textStyle(AppTypography.body(14, weight: .w600))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Scannable QR (QR tab).
private struct QrView: View {
    let ticket: TicketModel

    var body: some View {
        VStack(spacing: 0) {
            VGap(8)
            QrImageView(data: ticket.qrPayload, size: 180, color: AppColors.textPrimary)
                .padding(14)
                .boxDecoration(color: Colors.white, radius: 14, borderColor: AppColors.border)
            VGap(12)
            Text(ticket.bookingReference)
                .textStyle(AppTypography.heading(16, color: AppColors.primaryDark))
            VGap(4)
            Text(LocaleKeys.ticket_scan_at_gate_for_boarding_validation.tr())
                .textStyle(AppTypography.body(12, color: AppColors.textPrimary))
                .multilineTextAlignment(.center)
        }
    }
}

private struct EmptyState: View {
    let icon: IconData
    let message: String

    var body: some View {
        VStack(spacing: 0) {
            Icon(icon, size: 64, color: AppColors.textTertiary)
            VGap(16)
            Text(message)
                .textStyle(AppTypography.body(14, color: AppColors.textSecondary))
                .multilineTextAlignment(.center)
        }
    }
}

// ── QR (qr_flutter) ───────────────────────────────────────────────────────────

/// qr_flutter's `QrImageView(data:, version: auto, size:, eyeStyle: square,
/// dataModuleStyle: square)` with its default 10pt padding and error
/// correction level L, drawn from CoreImage's QR generator. Not in the
/// foundation, so it lives with its users (this page and the boarding pass).
struct QrImageView: View {
    let data: String
    var size: CGFloat
    /// Eye and data-module colour.
    var color: Color = Colors.black
    var padding: CGFloat = 10

    var body: some View {
        let modules = QrMatrix.modules(data)
        Canvas { context, canvasSize in
            guard !modules.isEmpty else { return }
            let count = modules.count
            let cell = min(canvasSize.width, canvasSize.height) / CGFloat(count)
            var path = Path()
            for (y, row) in modules.enumerated() {
                for (x, on) in row.enumerated() where on {
                    path.addRect(CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell))
                }
            }
            // Gapless: one fill, so neighbouring modules leave no seams.
            context.fill(path, with: .color(color))
        }
        .frame(width: max(size - padding * 2, 0), height: max(size - padding * 2, 0))
        .padding(padding)
    }
}

/// The QR symbol's module grid (row-major, true = dark), without the quiet zone.
private enum QrMatrix {
    private static let context = CIContext(options: [.useSoftwareRenderer: false])
    private static var cache: [String: [[Bool]]] = [:]

    static func modules(_ data: String) -> [[Bool]] {
        if let cached = cache[data] { return cached }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(data.utf8)
        filter.correctionLevel = "L"
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

        // CoreImage adds a quiet zone; crop to the dark modules' bounds (the
        // finder patterns sit on three corners, so the bounds are the symbol).
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where pixels[y * width + x] < 128 {
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return [] }
        let grid = (minY...maxY).map { y in
            (minX...maxX).map { x in pixels[y * width + x] < 128 }
        }
        cache[data] = grid
        return grid
    }
}
