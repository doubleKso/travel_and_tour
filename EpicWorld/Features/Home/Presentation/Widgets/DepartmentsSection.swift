// Port of lib/features/home/presentation/widgets/departments_section.dart

import SwiftUI

/// Which department(s) a `DepartmentsSection` should show.
enum DepartmentKind: String, CaseIterable, DartEnum {
    case ticket, visa, tour
}

/// Shared "Talk to the right team" block — department contact cards.
///
/// Sits at the bottom of both the Visa and Tour screens. `title` and
/// `subtitle` let each screen frame the block for its own context, and
/// `include` narrows it down to the department(s) relevant there — e.g. the
/// Visa screen only shows the Visa Department, the Tour screen only the Tour
/// Department. Each card shows a coloured header band (icon + tagline +
/// name) over a white body (blurb + three quick-action contact buttons).
struct DepartmentsSection: View {
    let title: String
    let subtitle: String
    let include: [DepartmentKind]

    init(
        title: String = "Our Departments",
        subtitle: String = "Every part of your journey is handled by a dedicated team, so "
            + "each step stays smooth from start to finish.",
        include: [DepartmentKind] = DepartmentKind.values
    ) {
        self.title = title
        self.subtitle = subtitle
        self.include = include
    }

    private static let departments: [DepartmentKind: Department] = [
        .ticket: Department(
            name: "Ticket Department",
            tagline: "FLIGHTS & TICKETING",
            description: "We handle all your flight bookings and ticketing needs, local or "
                + "international — the best routes, fares, and quick assistance.",
            asset: AppAssets.deptTicket,
            tint: AppColors.accent,
            contact: "+95 9 000 000 001"
        ),
        .visa: Department(
            name: "Visa Department",
            tagline: "APPLICATIONS & APPROVALS",
            description: "We take care of your visa processing with ease, providing reliable "
                + "guidance to help ensure a smooth approval process.",
            asset: AppAssets.deptVisa,
            tint: AppColors.primary,
            contact: "+95 9 000 000 002"
        ),
        .tour: Department(
            name: "Tour Department",
            tagline: "PACKAGES & EXPERIENCES",
            description: "Explore tailor-made local and international tour packages — from "
                + "group tours to custom adventures, planned down to every detail.",
            asset: AppAssets.deptTour,
            tint: AppColors.info,
            contact: "+95 9 000 000 003"
        ),
    ]

    var body: some View {
        let departments = include.compactMap { Self.departments[$0] }
        VStack(alignment: .leading, spacing: 0) {
            Reveal {
                VStack(spacing: 0) {
                    Text(title)
                        .textStyle(AppTypography.heading(22))
                        .multilineTextAlignment(.center)
                    VGap(6)
                    Text(subtitle)
                        .textStyle(AppTypography.body(13, color: AppColors.textSecondary, height: 1.4))
                        .multilineTextAlignment(.center)
                }
            }
            VGap(AppSpacing.lg)
            ForEach(Array(departments.enumerated()), id: \.offset) { i, department in
                // Cards follow the header (index + 1) so they cascade in after it.
                Reveal(index: i + 1, stagger: .milliseconds(110)) {
                    DepartmentCard(department: department)
                }
                if i != departments.count - 1 {
                    VGap(AppSpacing.md)
                }
            }
        }
    }
}

/// One department card — a custom SVG icon, name, short tagline, blurb, the
/// contact channels, and a contact number.
private struct Department {
    let name: String
    let tagline: String
    let description: String

    /// Path to the department's custom SVG icon (rendered white on its badge).
    let asset: String
    let tint: Color
    let contact: String
}

/// Circular glass icon badge for a department card header, with a soft ring
/// that continuously pulses outward — a small "we're active" heartbeat that
/// draws the eye to the icon without being distracting.
private struct PulsingIconBadge: View {
    let asset: String

    /// One 2200ms loop, repeated (`AnimationController..repeat()`).
    private static let period: TimeInterval = 2.2

    @State var start = Date()

    var body: some View {
        ZStack {
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSince(start)
                    .truncatingRemainder(dividingBy: Self.period) / Self.period
                Circle()
                    .stroke(Colors.white.withValues(alpha: 0.85), lineWidth: 1.4)
                    .padding(0.7)
                    .frame(width: 56, height: 56)
                    .scaleEffect(0.82 + t * 0.5)
                    .opacity((1 - t) * 0.55)
            }
            AppImage(asset, width: 27, height: 27, tint: Colors.white)
                .frame(width: 56, height: 56)
                .boxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    circle: true,
                    borderColor: Colors.white.withValues(alpha: 0.42),
                    shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 14, offset: Offset(0, 6))]
                )
        }
        .frame(width: 64, height: 64)
    }
}

/// Premium contact card: a coloured gradient header (glassy icon badge +
/// tagline chip + name) over a white body with the blurb and three circular
/// quick-action buttons (Call / Viber / Messenger).
private struct DepartmentCard: View {
    let department: Department

    private func openChannel(_ channel: Channel) {
        switch channel {
        case .call:
            Task { await ContactLauncher.dial(department.contact) }
        case .viber:
            Task { await ContactLauncher.viber(department.contact) }
        case .messenger:
            Task { await ContactLauncher.messenger(AppConsts.messengerPage) }
        }
    }

    var body: some View {
        let tint = department.tint
        VStack(alignment: .leading, spacing: 0) {
            // Coloured gradient header band — icon badge + tagline + name.
            HStack(spacing: 0) {
                PulsingIconBadge(asset: department.asset)
                HGap(14)
                VStack(alignment: .leading, spacing: 0) {
                    Text(department.tagline)
                        .textStyle(AppTypography.body(9.5, weight: .w700, color: Colors.white, letterSpacing: 0.8))
                        .padding(horizontal: 9, vertical: 4)
                        .boxDecoration(color: Colors.white.withValues(alpha: 0.22), radius: 20)
                    VGap(7)
                    Text(department.name)
                        .textStyle(AppTypography.heading(18, color: Colors.white))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(18, 20, 18, 22)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [tint, Color.lerp(tint, Colors.black, 0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            VStack(alignment: .leading, spacing: 0) {
                Text(department.description)
                    .textStyle(AppTypography.body(12.5, color: AppColors.textSecondary, height: 1.5))
                VGap(12)
                MaterialDivider(height: 1, color: AppColors.divider)
                // Quick-action contact icons — evenly spaced, big tap targets.
                HStack(spacing: 0) {
                    ForEach(Channel.values, id: \.self) { channel in
                        ChannelButton(channel: channel) { openChannel(channel) }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(18, 16, 18, 12)
        }
        .boxDecoration(
            color: AppColors.surface,
            radius: 26,
            shadows: [BoxShadow(color: tint.withValues(alpha: 0.18), blurRadius: 24, offset: Offset(0, 12))]
        )
    }
}

/// A contact channel shown as a circular quick-action icon under a department.
private enum Channel: String, CaseIterable, DartEnum {
    case call, viber, messenger

    /// Real brand glyph for the channel (rendered white on its coloured badge).
    var asset: String {
        switch self {
        case .call: return AppAssets.channelCall
        case .viber: return AppAssets.channelViber
        case .messenger: return AppAssets.channelMessenger
        }
    }

    var color: Color {
        switch self {
        case .call: return Color(0xFF25A244)
        case .viber: return Color(0xFF7360F2)
        case .messenger: return Color(0xFF0084FF)
        }
    }

    var label: String {
        switch self {
        case .call: return "Call"
        case .viber: return "Viber"
        case .messenger: return "Messenger"
        }
    }
}

/// One circular quick-action contact button (icon badge + label), sized to
/// share a row evenly with its siblings via the parent's `Expanded`.
private struct ChannelButton: View {
    let channel: Channel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                AppImage(channel.asset, width: 19, height: 19, tint: Colors.white)
                    .frame(width: 44, height: 44)
                    .boxDecoration(
                        gradient: LinearGradient(
                            colors: [Color.lerp(channel.color, Colors.white, 0.25), channel.color],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        radius: 14,
                        shadows: [BoxShadow(color: channel.color.withValues(alpha: 0.35), blurRadius: 10, offset: Offset(0, 5))]
                    )
                VGap(7)
                Text(channel.label)
                    .textStyle(AppTypography.body(11, weight: .w600, color: AppColors.textPrimary))
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.ink(radius: 18))
        .accessibilityLabel(channel.label)
    }
}

/// Automatic entrance animation — fades, slides up, and scales its `content` in.
/// `index` × `stagger` delays the start so the section reveals one-by-one.
private struct Reveal<Content: View>: View {
    var index = 0
    var stagger: Duration = .milliseconds(70)
    @ViewBuilder var content: Content

    @State var shown = false
    @State var height: CGFloat = 0

    var body: some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { height = proxy.size.height }
                        .onChange(of: proxy.size.height) { _, newHeight in height = newHeight }
                }
            )
            .scaleEffect(shown ? 1 : 0.94)
            // SlideTransition: `Offset(0, 0.16)` is a fraction of the child's height.
            .offset(y: shown ? 0 : height * 0.16)
            .opacity(shown ? 1 : 0)
            .task {
                try? await Task.sleep(for: stagger * index)
                guard !Task.isCancelled else { return }
                // 480ms, Curves.easeOutCubic.
                withAnimation(.timingCurve(0.215, 0.61, 0.355, 1, duration: 0.48)) { shown = true }
            }
    }
}
