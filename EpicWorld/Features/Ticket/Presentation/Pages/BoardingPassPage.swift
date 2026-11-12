// Port of lib/features/ticket/presentation/pages/boarding_pass_page.dart
import SwiftUI

/// BOARDING PASS / E-TICKET — shown after a successful payment.
///
/// On arrival a modern "Booking Confirmed" dialog is presented; dismissing it
/// reveals the boarding pass (brand-green theme, QR validation code, and
/// Download / Back-to-Home actions).
struct BoardingPassPage: View {
    let ticket: TicketModel

    init(ticket: TicketModel) {
        self.ticket = ticket
    }

    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router

    /// `initState` runs once; `.task` runs on every appearance.
    @State private var confirmedDialogShown = false

    // ---- Deterministic display values (mock — would come from the airline). ----
    private var seed: Int { abs(dartHashCode(ticket.bookingReference)) }
    private var checkIn: String { "A\(10 + seed % 20)" }
    private var gate: String { "\(seed % 9 + 1)" }
    private var terminal: String { "C\(seed % 5 + 1)" }
    private var seats: String {
        let row = seed % 30 + 1
        let letters = ["A", "B", "C", "D", "E", "F"]
        let start = seed % 3
        let count = min(max(ticket.seatCount, 1), 4)
        return (0..<count).map { "\(row)\(letters[(start + $0) % 6])" }.joined(separator: ", ")
    }

    private var ticketCode: String { "A\(1000 + seed % 9000)KL\(100 + seed % 900)" }

    private func backToHome() {
        container.flightBookingBloc.add(.bookingReset)
        router.popUntilRoot()
    }

    private func showConfirmedDialog() async {
        let _: Void? = await showDialog(barrierDismissible: false) { dismiss in
            BookingConfirmedDialog(
                bookingRef: ticket.bookingReference,
                onClose: { dismiss(nil) }
            )
        }
    }

    var body: some View {
        let t = ticket.outbound

        ZStack {
            // ---- Shaded, decorated backdrop ----
            ShadedBackground()
                .ignoresSafeArea()
            // ---- Content ----
            VStack(spacing: 0) {
                Header(
                    onBack: backToHome,
                    onShare: { SnackBarCenter.shared.show(LocaleKeys.ticket_sharing_e_ticket.tr()) }
                )
                ScrollView {
                    VStack(spacing: 0) {
                        BoardingPassCard(
                            ticket: ticket,
                            leg: t,
                            checkIn: checkIn,
                            gate: gate,
                            seats: seats,
                            terminal: terminal,
                            ticketCode: ticketCode,
                            notchColor: AppColors.primary
                        )
                        VGap(18)
                        ActionPanel(
                            onDownload: { SnackBarCenter.shared.show(LocaleKeys.ticket_downloading_e_ticket.tr()) },
                            onHome: backToHome
                        )
                    }
                    .padding(20, 8, 20, 24)
                }
            }
        }
        .background(AppColors.primary.ignoresSafeArea())
        .task {
            guard !confirmedDialogShown else { return }
            confirmedDialogShown = true
            await showConfirmedDialog()
        }
    }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------
private struct Header: View {
    let onBack: () -> Void
    let onShare: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            circleButton(Icons.arrow_back, onBack)
            Text(LocaleKeys.ticket_boarding_pass.tr())
                .textStyle(AppTypography.heading(20, color: Colors.white))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            circleButton(Icons.ios_share, onShare)
        }
        .padding(16, 12, 16, 12)
    }

    private func circleButton(_ icon: IconData, _ onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Icon(icon, size: 20, color: Colors.white)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Colors.white.withValues(alpha: 0.18)))
        }
        .buttonStyle(.plain)
    }
}

// ---------------------------------------------------------------------------
// Shaded, decorated backdrop
// ---------------------------------------------------------------------------
private struct ShadedBackground: View {
    var body: some View {
        ZStack {
            // Base brand colour (keeps the ticket notches seamless).
            AppColors.primary
            // Soft top highlight + bottom shade for depth.
            LinearGradient(
                stops: [
                    .init(color: AppColors.primaryLight.withValues(alpha: 0.35), location: 0),
                    .init(color: AppColors.primary, location: 0.45),
                    .init(color: AppColors.primaryDark.withValues(alpha: 0.9), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        // Faint decorative blobs.
        .overlay(alignment: .topTrailing) { blob(190, 0.07).offset(x: 40, y: -50) }
        .overlay(alignment: .topLeading) { blob(220, 0.05).offset(x: -70, y: 160) }
        .overlay(alignment: .bottomTrailing) { blob(180, 0.06).offset(x: 30, y: 60) }
        .clipped()
    }

    private func blob(_ size: CGFloat, _ opacity: Double) -> some View {
        Circle()
            .fill(Colors.white.withValues(alpha: opacity))
            .frame(width: size, height: size)
    }
}

// ---------------------------------------------------------------------------
// Boarding pass card
// ---------------------------------------------------------------------------
private struct BoardingPassCard: View {
    let ticket: TicketModel
    let leg: TripOptionModel
    let checkIn: String
    let gate: String
    let seats: String
    let terminal: String
    let ticketCode: String
    let notchColor: Color

    var body: some View {
        VStack(spacing: 0) {
            // ---- Airline + booking ref ----
            HStack(spacing: 0) {
                AirlineBrandBadge(operator: leg.operatorName, size: 44)
                HGap(10)
                VStack(alignment: .leading, spacing: 0) {
                    Text(leg.operatorName)
                        .textStyle(AppTypography.heading(16))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    VGap(4)
                    Text(leg.travelClass.label)
                        .textStyle(AppTypography.body(10, weight: .w700, color: AppColors.primaryDark))
                        .padding(horizontal: 8, vertical: 3)
                        .boxDecoration(color: AppColors.primarySurface, radius: 20)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("#\(ticket.bookingReference.replacingOccurrences(of: "EW-", with: ""))")
                    .textStyle(AppTypography.body(13, weight: .w700, color: AppColors.textSecondary))
            }
            .padding(20, 20, 20, 16)
            MaterialDivider(height: 1, color: AppColors.dividerLight)

            // ---- Route ----
            HStack(alignment: .top, spacing: 0) {
                routeEnd(leg.originCode, leg.originName, Formatters.time(leg.departure), false)
                routeMiddle(leg)
                    .frame(maxWidth: .infinity)
                routeEnd(leg.destinationCode, leg.destinationName, Formatters.time(leg.arrival), true)
            }
            .padding(20, 18, 20, 18)

            Perforation(notchColor: notchColor)

            // ---- Info grid ----
            VStack(spacing: 0) {
                infoRow(Icons.login_rounded, "Check In", checkIn,
                        Icons.meeting_room_outlined, "Gate", gate)
                MaterialDivider(height: 24, color: AppColors.dividerLight)
                infoRow(Icons.event_seat_outlined, "Seats", seats,
                        Icons.apartment_rounded, "Terminal", terminal)
                MaterialDivider(height: 24, color: AppColors.dividerLight)
                infoRow(Icons.workspace_premium_outlined, "Seat Class", leg.travelClass.label,
                        Icons.calendar_today, "Date", Formatters.fullDate(leg.departure))
                VGap(18)
                Text(ticket.passengerName).textStyle(AppTypography.heading(20))
                VGap(2)
                Text(LocaleKeys.ticket_passenger.tr())
                    .textStyle(AppTypography.body(12, color: AppColors.textPrimary))
                VGap(8)
            }
            .padding(horizontal: 20, vertical: 6)

            Perforation(notchColor: notchColor)

            // ---- Ticket code + QR ----
            VStack(spacing: 0) {
                Text(LocaleKeys.ticket_ticket_code.tr(args: [ticketCode]))
                    .textStyle(AppTypography.body(14, weight: .w700))
                VGap(16)
                QrImageView(data: ticket.qrPayload, size: 150, color: AppColors.textPrimary)
                    .padding(12)
                    .boxDecoration(color: Colors.white, radius: 12, borderColor: AppColors.border)
                VGap(10)
                Text(LocaleKeys.ticket_scan_at_gate_for_validation.tr())
                    .textStyle(AppTypography.body(11, color: AppColors.textPrimary))
            }
            .padding(20, 16, 20, 24)
        }
        .frame(maxWidth: .infinity)
        // A Container decoration does not clip its children here, so the
        // perforation notches overhang the card edges.
        .background(
            Color.clear.boxDecoration(
                color: AppColors.surface,
                radius: 26,
                shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 30, offset: Offset(0, 14))]
            )
        )
    }

    private func routeEnd(_ code: String, _ city: String, _ time: String, _ end: Bool) -> some View {
        VStack(alignment: end ? .trailing : .leading, spacing: 0) {
            Text(code).textStyle(AppTypography.heading(30))
            VGap(2)
            Text(city).textStyle(AppTypography.body(12, color: AppColors.textPrimary))
            VGap(6)
            Text(time).textStyle(AppTypography.heading(18))
        }
    }

    private func routeMiddle(_ leg: TripOptionModel) -> some View {
        VStack(spacing: 0) {
            Text(Formatters.duration(leg.duration))
                .textStyle(AppTypography.body(12, weight: .w600, color: AppColors.textSecondary))
            VGap(6)
            HStack(spacing: 0) {
                Icon(leg.mode == .flight ? Icons.flight : Icons.directions_bus, size: 18, color: AppColors.primary)
                dashes()
                    .frame(maxWidth: .infinity)
                Circle()
                    .strokeBorder(AppColors.primary, lineWidth: 1.6)
                    .frame(width: 7, height: 7)
            }
            VGap(6)
            Text(leg.isDirect ? "Non-stop" : "\(leg.stops) stop(s)")
                .textStyle(AppTypography.body(12, color: AppColors.textPrimary))
        }
        .padding(horizontal: 8, vertical: 6)
    }

    private func dashes() -> some View {
        GeometryReader { proxy in
            let dash: CGFloat = 5.0
            let count = min(max(Int((proxy.size.width / (dash * 2)).rounded(.down)), 1), 30)
            HStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { index in
                    if index > 0 { Spacer(minLength: 0) }
                    Rectangle()
                        .fill(AppColors.dividerLight)
                        .frame(width: dash, height: 1.4)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
        }
        .frame(height: 1.4)
        .padding(.horizontal, 4)
    }

    private func infoRow(
        _ i1: IconData, _ l1: String, _ v1: String,
        _ i2: IconData, _ l2: String, _ v2: String
    ) -> some View {
        HStack(alignment: .top, spacing: 0) {
            infoCell(i1, l1, v1, false)
            infoCell(i2, l2, v2, true)
        }
    }

    private func infoCell(_ icon: IconData, _ label: String, _ value: String, _ end: Bool) -> some View {
        VStack(alignment: end ? .trailing : .leading, spacing: 0) {
            HStack(spacing: 0) {
                if end {
                    Text(label).textStyle(AppTypography.body(11, color: AppColors.textPrimary))
                    HGap(5)
                    Icon(icon, size: 14, color: AppColors.primary)
                } else {
                    Icon(icon, size: 14, color: AppColors.primary)
                    HGap(5)
                    Text(label).textStyle(AppTypography.body(11, color: AppColors.textPrimary))
                }
            }
            VGap(4)
            Text(value).textStyle(AppTypography.heading(18))
        }
        .frame(maxWidth: .infinity, alignment: end ? .trailing : .leading)
    }
}

/// Dashed seam with concave side notches (the torn-ticket effect).
private struct Perforation: View {
    let notchColor: Color

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<28, id: \.self) { index in
                if index > 0 { Spacer(minLength: 0) }
                Rectangle()
                    .fill(AppColors.dividerLight)
                    .frame(width: 6, height: 1.4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 22, alignment: .top)
        .overlay(alignment: .leading) { notch().offset(x: -11) }
        .overlay(alignment: .trailing) { notch().offset(x: 11) }
    }

    private func notch() -> some View {
        Circle()
            .fill(notchColor)
            .frame(width: 22, height: 22)
    }
}

// ---------------------------------------------------------------------------
// Bottom action panel
// ---------------------------------------------------------------------------
private struct ActionPanel: View {
    let onDownload: () -> Void
    let onHome: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onDownload) {
                HStack(spacing: 0) {
                    Icon(Icons.download_rounded, size: 20)
                    HGap(8)
                    Text(LocaleKeys.ticket_download_e_ticket.tr())
                        .textStyle(AppTypography.body(16, weight: .w700, color: Colors.white))
                }
            }
            .buttonStyle(ElevatedButtonStyle())
            .frame(height: 54)
            VGap(10)
            Button(action: onHome) {
                HStack(spacing: 0) {
                    Icon(Icons.home_outlined, size: 20)
                    HGap(8)
                    // The theme's OutlinedButton label style.
                    Text(LocaleKeys.common_back_to_home.tr())
                        .textStyle(AppTypography.body(16, weight: .w600, color: AppColors.primary))
                }
            }
            .buttonStyle(OutlinedButtonStyle(minimumHeight: 52))
            .frame(height: 52)
        }
        .padding(16)
        .boxDecoration(color: AppColors.surface, radius: 24)
    }
}

// ---------------------------------------------------------------------------
// Booking confirmed dialog
// ---------------------------------------------------------------------------
private struct BookingConfirmedDialog: View {
    let bookingRef: String
    let onClose: () -> Void

    init(bookingRef: String, onClose: @escaping () -> Void) {
        self.bookingRef = bookingRef
        self.onClose = onClose
    }

    /// The entrance controller (1000 ms) and the confetti (1100 ms of
    /// emission) both start when the dialog appears.
    @State private var start = Date()
    @State private var confetti = ConfettiSystem()
    @State private var finished = false

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: finished)) { context in
            let elapsed = max(context.date.timeIntervalSince(start), 0)
            let entrance = min(elapsed / 1.0, 1)
            ZStack {
                // Confetti — an explosive center burst plus two corner cannons.
                ConfettiCanvas(system: confetti, elapsed: elapsed)
                    .allowsHitTesting(false)
                // Dialog pops in with a scale + fade.
                card(elapsed: elapsed, entrance: entrance)
                    .padding(.horizontal, 32)
                    .scaleEffect(max(CurveMath.easeOutBack(entrance), 0.0001))
                    .opacity(entrance)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // The modal host insets dialogs by 40 / 24; this route fills the safe
        // area (`SizedBox.expand`) like the Dart dialog.
        .padding(.horizontal, -40)
        .padding(.vertical, -24)
        .task {
            // Stop redrawing once the entrance and the confetti are done.
            try? await Task.sleep(for: .seconds(ConfettiSystem.lifetime))
            finished = true
        }
    }

    private func card(elapsed: Double, entrance: Double) -> some View {
        VStack(spacing: 0) {
            CelebrationCheck(progress: min(elapsed / 1.1, 1))
            VGap(20)
            stagger(0, entrance) {
                Text(LocaleKeys.ticket_booking_confirmed.tr())
                    .textStyle(AppTypography.heading(22))
            }
            VGap(8)
            stagger(1, entrance) {
                Text(LocaleKeys.ticket_payment_was_successful_and_e_ticket.tr())
                    .textStyle(AppTypography.body(13, color: AppColors.textSecondary, height: 1.4))
                    .multilineTextAlignment(.center)
            }
            VGap(14)
            stagger(2, entrance) {
                Text(LocaleKeys.ticket_booking_ref.tr(args: [bookingRef]))
                    .textStyle(AppTypography.body(13, weight: .w700, color: AppColors.primaryDark))
                    .padding(horizontal: 14, vertical: 8)
                    .boxDecoration(color: AppColors.primarySurface, radius: 30)
            }
            VGap(24)
            stagger(3, entrance) {
                Button(action: onClose) {
                    Text(LocaleKeys.ticket_view_boarding_pass.tr())
                        .textStyle(AppTypography.body(15, weight: .w700, color: Colors.white))
                }
                .buttonStyle(ElevatedButtonStyle(minimumHeight: 52))
                .frame(height: 52)
            }
        }
        .padding(28, 32, 28, 24)
        .frame(maxWidth: .infinity)
        .boxDecoration(color: AppColors.surface, radius: 24)
    }

    /// Fade + slide-up a child on a staggered schedule for a lively reveal.
    private func stagger<Content: View>(
        _ order: Int,
        _ progress: Double,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        let begin = min(max(0.25 + Double(order) * 0.13, 0.0), 0.85)
        let value = CurveMath.easeOut(CurveMath.interval(progress, begin, min(max(begin + 0.4, 0.0), 1.0)))
        return content()
            .opacity(value)
            .offset(y: 14 * (1 - value))
    }
}

/// Check badge that pops in with an elastic bounce and a pulsing ring.
private struct CelebrationCheck: View {
    /// The 1100 ms controller's value.
    let progress: Double

    var body: some View {
        let pop = CurveMath.elasticOut(CurveMath.interval(progress, 0, 0.6))
        let ring = CurveMath.easeOut(CurveMath.interval(progress, 0.1, 1))
        ZStack {
            // Expanding, fading pulse ring.
            Circle()
                .strokeBorder(AppColors.primary, lineWidth: 2)
                .frame(width: 70 + 40 * ring, height: 70 + 40 * ring)
                .opacity(min(max(1 - ring, 0), 1) * 0.5)
            // Soft halo.
            Circle()
                .fill(AppColors.primarySurface)
                .frame(width: 92, height: 92)
            // Popping check badge.
            Icon(Icons.check_rounded, size: 38, color: Colors.white)
                .frame(width: 64, height: 64)
                .background(Circle().fill(AppColors.primaryGradient))
                .scaleEffect(max(pop, 0.0001))
        }
        .frame(width: 110, height: 110)
    }
}

// ---------------------------------------------------------------------------
// Confetti (the `confetti` package's ConfettiWidget)
// ---------------------------------------------------------------------------

/// Three emitters as the Dart dialog configures them — explosive at the top
/// centre (24 particles), and directional cannons at the top-left (π/4,
/// down-right) and top-right (3π/4, down-left) with 14 each — `maxBlastForce`
/// 24, `minBlastForce` 8, `emissionFrequency` 0.04, `gravity` 0.3, emitting for
/// 1100 ms without looping, in the brand colours. The physics follow the
/// package's per-frame model (start-up force for 5 frames, quadratic drag 0.05,
/// gravity lerp(0.1, 5, 0.3), all divided by a random 1–11 mass).
private final class ConfettiSystem {
    struct Particle {
        let emitter: Int
        let birthFrame: Int
        let size: CGSize
        let color: Color
        let spin: Double
        let flutter: Double
        /// Offset from the emitter, one per 60 fps frame of its life.
        let path: [CGPoint]
    }

    static let fps = 60.0
    static let lifetime = 6.0
    private static let emissionFrames = 66 // 1100 ms
    private static let colors = [AppColors.primary, AppColors.primaryLight, AppColors.accent, Colors.white]

    let particles: [Particle]

    init() {
        var generator = SystemRandomNumberGenerator()
        // (blast direction, explosive, numberOfParticles)
        let emitters: [(direction: Double, explosive: Bool, count: Int)] = [
            (0, true, 24),
            (Double.pi / 4, false, 14),
            (3 * Double.pi / 4, false, 14),
        ]
        var list: [Particle] = []
        for frame in 0..<Self.emissionFrames {
            for (index, emitter) in emitters.enumerated() {
                let emits = frame == 0 || Double.random(in: 0..<1, using: &generator) < 0.04
                guard emits else { continue }
                for _ in 0..<emitter.count {
                    list.append(Self.particle(
                        emitter: index,
                        direction: emitter.direction,
                        explosive: emitter.explosive,
                        birthFrame: frame,
                        using: &generator
                    ))
                }
            }
        }
        particles = list
    }

    private static func particle(
        emitter: Int,
        direction: Double,
        explosive: Bool,
        birthFrame: Int,
        using generator: inout SystemRandomNumberGenerator
    ) -> Particle {
        let angle = explosive
            ? Double.random(in: 0..<(2 * Double.pi), using: &generator)
            : direction + Double.random(in: -0.4...0.4, using: &generator)
        let force = Double.random(in: 8...24, using: &generator)
        let mass = Double.random(in: 1...11, using: &generator)
        let gravity = 0.1 + (5 - 0.1) * 0.3
        let drag = 0.05

        var position = CGPoint.zero
        var velocity = (x: Double.random(in: -3...3, using: &generator), y: Double.random(in: -3...3, using: &generator))
        let startUp = (x: cos(angle) * force, y: sin(angle) * force)
        let frames = Int(lifetime * fps) - birthFrame
        var path: [CGPoint] = []
        path.reserveCapacity(max(frames, 0))
        for age in 0..<max(frames, 0) {
            var acceleration = (x: 0.0, y: 0.0)
            let speed = (velocity.x * velocity.x + velocity.y * velocity.y).squareRoot()
            if speed > 0 {
                let magnitude = drag * speed * speed
                acceleration.x += -velocity.x / speed * magnitude / mass
                acceleration.y += -velocity.y / speed * magnitude / mass
            }
            if age < 5 {
                acceleration.x += startUp.x / mass
                acceleration.y += startUp.y / mass
            }
            acceleration.y += gravity / mass
            velocity.x += acceleration.x
            velocity.y += acceleration.y
            position.x += CGFloat(velocity.x)
            position.y += CGFloat(velocity.y)
            path.append(position)
        }

        let width = CGFloat(Double.random(in: 20...30, using: &generator))
        let height = CGFloat(Double.random(in: 10...15, using: &generator))
        return Particle(
            emitter: emitter,
            birthFrame: birthFrame,
            size: CGSize(width: width, height: height),
            color: colors[Int.random(in: 0..<colors.count, using: &generator)],
            spin: Double.random(in: -8...8, using: &generator),
            flutter: Double.random(in: 4...10, using: &generator),
            path: path
        )
    }
}

private struct ConfettiCanvas: View {
    let system: ConfettiSystem
    let elapsed: Double

    var body: some View {
        Canvas { context, size in
            let frame = Int(elapsed * ConfettiSystem.fps)
            for particle in system.particles {
                let age = frame - particle.birthFrame
                guard age >= 0, age < particle.path.count else { continue }
                let emitterOrigin: CGPoint
                switch particle.emitter {
                case 0: emitterOrigin = CGPoint(x: size.width / 2, y: 0)
                case 1: emitterOrigin = .zero
                default: emitterOrigin = CGPoint(x: size.width, y: 0)
                }
                let offset = particle.path[age]
                let point = CGPoint(x: emitterOrigin.x + offset.x, y: emitterOrigin.y + offset.y)
                guard point.y < size.height + 40, point.x > -40, point.x < size.width + 40 else { continue }
                let seconds = Double(age) / ConfettiSystem.fps
                var copy = context
                copy.translateBy(x: point.x, y: point.y)
                copy.rotate(by: .radians(particle.spin * seconds))
                // Paper flutter: the strip turns over around its long axis.
                let turn = max(abs(cos(particle.flutter * seconds)), 0.15)
                let rect = CGRect(
                    x: -particle.size.width / 2,
                    y: -particle.size.height * turn / 2,
                    width: particle.size.width,
                    height: particle.size.height * turn
                )
                copy.fill(Path(rect), with: .color(particle.color))
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Flutter curves used by the dialog
// ---------------------------------------------------------------------------
private enum CurveMath {
    /// `Interval(begin, end)` before its curve.
    static func interval(_ t: Double, _ begin: Double, _ end: Double) -> Double {
        guard end > begin else { return t >= end ? 1 : 0 }
        return min(max((t - begin) / (end - begin), 0), 1)
    }

    /// `Curves.easeOut` = Cubic(0.0, 0.0, 0.58, 1.0).
    static func easeOut(_ t: Double) -> Double { cubic(0.0, 0.0, 0.58, 1.0, t) }

    /// `Curves.easeOutBack` = Cubic(0.175, 0.885, 0.32, 1.275).
    static func easeOutBack(_ t: Double) -> Double { cubic(0.175, 0.885, 0.32, 1.275, t) }

    /// `Curves.elasticOut` = ElasticOutCurve(0.4).
    static func elasticOut(_ t: Double) -> Double {
        if t == 0 || t == 1 { return t }
        let period = 0.4
        let s = period / 4.0
        return pow(2.0, -10 * t) * sin((t - s) * (Double.pi * 2.0) / period) + 1.0
    }

    /// Flutter's `Cubic.transform` (bisection to within 0.001).
    private static func cubic(_ a: Double, _ b: Double, _ c: Double, _ d: Double, _ t: Double) -> Double {
        if t == 0 || t == 1 { return t }
        func evaluate(_ p: Double, _ q: Double, _ m: Double) -> Double {
            3 * p * (1 - m) * (1 - m) * m + 3 * q * (1 - m) * m * m + m * m * m
        }
        var start = 0.0
        var end = 1.0
        for _ in 0..<64 {
            let midpoint = (start + end) / 2
            let estimate = evaluate(a, c, midpoint)
            if abs(t - estimate) < 0.001 { return evaluate(b, d, midpoint) }
            if estimate < t { start = midpoint } else { end = midpoint }
        }
        return evaluate(b, d, (start + end) / 2)
    }
}

/// Dart VM `String.hashCode` (Jenkins one-at-a-time over UTF-16 code units,
/// 30-bit), so the mock gate / seat values match the Flutter app's.
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
