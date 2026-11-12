// Port of lib/features/booking/presentation/widgets/trip_summary_card.dart
import SwiftUI

/// Collapsible **Trip Summary** card — a vertical, pin-connected timeline of the
/// selected flight legs (Departure → Return), each showing the airline, route,
/// times and date · class. Used on both the Passenger Details and Payment
/// screens.
///
/// When `contactName` (or phone / email) is supplied, a Contact Information
/// section is appended below the legs; otherwise it's omitted (e.g. the
/// Passenger Details screen already collects contact info in its form).
struct TripSummaryCard: View {
    let outbound: TripOptionModel
    let inbound: TripOptionModel?
    let contactName: String?
    let contactPhone: String?
    let contactEmail: String?
    let initiallyExpanded: Bool

    /// Shows a "Booked" badge beside the "Trip Summary" title — History uses
    /// this for unpaid reservations.
    let isReservation: Bool

    /// When provided the whole card becomes a tap target (e.g. a History list
    /// item opening the ticket detail). In this mode the card stays expanded and
    /// the header shows a "›" chevron instead of the collapse toggle.
    let onTap: (() -> Void)?

    /// `late bool _expanded = widget.initiallyExpanded;`
    @State private var expanded: Bool

    init(
        outbound: TripOptionModel,
        inbound: TripOptionModel? = nil,
        contactName: String? = nil,
        contactPhone: String? = nil,
        contactEmail: String? = nil,
        initiallyExpanded: Bool = true,
        isReservation: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.outbound = outbound
        self.inbound = inbound
        self.contactName = contactName
        self.contactPhone = contactPhone
        self.contactEmail = contactEmail
        self.initiallyExpanded = initiallyExpanded
        self.isReservation = isReservation
        self.onTap = onTap
        _expanded = State(initialValue: initiallyExpanded)
    }

    // Space between the Departure and Return blocks — shared by the pin column
    // and the content column so the second pin always lands at the top of the
    // Return block.
    private static let legGap: CGFloat = 34

    private var hasContact: Bool {
        contactName != nil || contactPhone != nil || contactEmail != nil
    }

    var body: some View {
        let isOneWay = inbound == nil
        // Tappable mode (History list): whole card opens detail, stays expanded.
        let tappable = onTap != nil
        let showBody = tappable || expanded

        let card = VStack(alignment: .leading, spacing: 0) {
            // Header — collapse toggle in card mode, plain in tappable mode.
            if tappable {
                header(tappable: tappable)
            } else {
                header(tappable: tappable)
                    .contentShape(Rectangle())
                    .onTapGesture { expanded.toggle() }
            }
            // Body — AnimatedSize(220ms, easeOutCubic, alignment: topCenter):
            // collapsed is a zero-height box, expanded the full body.
            bodyContent(isOneWay: isOneWay)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: showBody ? nil : 0, alignment: .top)
                .clipped()
                .accessibilityHidden(!showBody)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .animation(.timingCurve(0.215, 0.61, 0.355, 1, duration: 0.22), value: showBody)

        if tappable {
            card
                .contentShape(Rectangle())
                .onTapGesture { onTap?() }
        } else {
            card
        }
    }

    private func header(tappable: Bool) -> some View {
        HStack(spacing: 0) {
            Text(LocaleKeys.booking_trip_summary.tr())
                .textStyle(AppTypography.body(15, weight: .w700, color: AppColors.textPrimary))
            Spacer(minLength: 0)
            // Right-side affordance. The old "›" chevron is removed; History
            // reservations now surface the "Booked" badge here instead. The
            // collapsible mode (Payment / Passenger details) keeps its arrow.
            if isReservation {
                ReservedBadge()
            } else if !tappable {
                Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: AppColors.primary)
                    .rotationEffect(.degrees(expanded ? 180 : 0))
                    .animation(.linear(duration: 0.2), value: expanded)
            }
        }
        .padding(16, 14, 14, 14)
    }

    private func bodyContent(isOneWay: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MaterialDivider(height: 1, color: AppColors.dividerLight)
            // Flight legs with the pin timeline.
            legs(isOneWay: isOneWay)
                .padding(16, 16, 16, 14)
            if hasContact {
                DashedLineView()
                    .padding(horizontal: 16, vertical: 4)
                contactSection
                    .padding(16, 12, 16, 16)
            } else {
                VGap(2)
            }
        }
    }

    private func legs(isOneWay: Bool) -> some View {
        // Leg content, offset right to clear the pin column.
        VStack(alignment: .leading, spacing: 0) {
            LegBlock(
                leg: outbound,
                label: isOneWay ? "One Way" : "Departure",
                color: isOneWay ? AppColors.primary : AppColors.info
            )
            if let inbound {
                VGap(Self.legGap)
                LegBlock(
                    leg: inbound,
                    label: LocaleKeys.common_return.tr(),
                    color: AppColors.error
                )
            }
        }
        .padding(.leading, 36)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Pin timeline stretched to the content height
        // (Positioned(left: 0, top: 0, bottom: 0, width: 26)).
        .overlay(alignment: .topLeading) {
            VStack(spacing: 0) {
                Pin(color: isOneWay ? AppColors.primary : AppColors.info)
                // Dotted line runs from under each pin down alongside its leg
                // content (to the date).
                if isOneWay {
                    VerticalDash()
                        .frame(maxHeight: .infinity)
                } else {
                    VerticalDash()
                        .frame(maxHeight: .infinity)
                    VerticalDash()
                        .frame(height: Self.legGap)
                    Pin(color: AppColors.error)
                    VerticalDash()
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 26)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(LocaleKeys.booking_contact_information.tr())
                .textStyle(AppTypography.heading(15))
            VGap(12)
            if let contactName {
                ContactRow(icon: Icons.person_outline_rounded, value: contactName)
            }
            if let contactPhone {
                VGap(10)
                ContactRow(icon: Icons.phone_outlined, value: contactPhone)
            }
            if let contactEmail {
                VGap(10)
                ContactRow(icon: Icons.mail_outline_rounded, value: contactEmail)
            }
        }
    }
}

/// One leg's content: airline row + route codes + times + date · class.
private struct LegBlock: View {
    let leg: TripOptionModel
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Airline + status badge.
            HStack(spacing: 0) {
                AirlineLogo(
                    name: leg.operatorName,
                    logoUrl: leg.operatorLogoUrl,
                    carrierCode: leg.carrierCode,
                    size: 34
                )
                HGap(10)
                Text(leg.operatorName)
                    .textStyle(AppTypography.body(12.5, weight: .w600, color: AppColors.textSecondary))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                StatusBadge(label: label, color: color)
            }
            VGap(8)
            // Route codes with a plane between.
            HStack(spacing: 0) {
                Text(leg.originCode).textStyle(AppTypography.heading(17))
                Icon(Icons.flight, size: 14, color: AppColors.primary)
                    .rotationEffect(.radians(1.5708))
                    .padding(.horizontal, 8)
                Text(leg.destinationCode).textStyle(AppTypography.heading(17))
            }
            VGap(5)
            // Times (icon removed).
            Text("\(Formatters.time12(leg.departure))  →  \(Formatters.time12(leg.arrival))")
                .textStyle(AppTypography.body(12.5, weight: .w600, color: AppColors.primary))
            VGap(3)
            // Date · class (icon removed).
            Text("\(DateFormat("d MMM yyyy").format(leg.departure))  ·  \(leg.travelClass.label)")
                .textStyle(AppTypography.body(12, color: AppColors.textSecondary))
        }
    }
}

/// A location pin marker sitting in the timeline column.
private struct Pin: View {
    let color: Color

    var body: some View {
        Icon(Icons.location_on, size: 24, color: color)
    }
}

/// Small "Departure" / "Return" / "One Way" pill next to the airline name.
private struct StatusBadge: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .textStyle(AppTypography.body(11, weight: .w700, color: color))
            .padding(horizontal: 10, vertical: 4)
            .boxDecoration(color: color.withValues(alpha: 0.12), radius: 20)
    }
}

/// Amber "Booked" badge shown beside the title for unpaid reservations.
private struct ReservedBadge: View {
    var body: some View {
        HStack(spacing: 0) {
            Icon(Icons.bookmark_rounded, size: 11, color: Colors.white)
            HGap(4)
            Text(LocaleKeys.common_booked.tr())
                .textStyle(AppTypography.body(10.5, weight: .w800, color: Colors.white))
        }
        .padding(horizontal: 10, vertical: 4)
        .boxDecoration(color: AppColors.accent, radius: 20)
    }
}

/// One contact row: an icon + value.
private struct ContactRow: View {
    let icon: IconData
    let value: String

    var body: some View {
        HStack(spacing: 0) {
            Icon(icon, size: 17, color: AppColors.primary)
            HGap(12)
            Text(value)
                .textStyle(AppTypography.body(13, weight: .w500, color: AppColors.textPrimary))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A thin horizontal dashed separator (Dart `_DashedLine`; renamed so it does
/// not clash with the foundation's `DashedLine`).
private struct DashedLineView: View {
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

/// A vertical dashed connector that stretches to fill its given height, so it
/// always spans the gap between the two pins.
private struct VerticalDash: View {
    var body: some View {
        Canvas { context, size in
            let dashW: CGFloat = 2.0
            let dashH: CGFloat = 4.0
            let gap: CGFloat = 3.0
            let count = Int((size.height / (dashH + gap)).rounded(.down))
            if count <= 0 { return }
            let x = (size.width - dashW) / 2
            var y: CGFloat = 0.0
            for _ in 0..<count {
                context.fill(
                    Path(roundedRect: CGRect(x: x, y: y, width: dashW, height: dashH), cornerRadius: 1),
                    with: .color(AppColors.border)
                )
                y += dashH + gap
            }
        }
    }
}
