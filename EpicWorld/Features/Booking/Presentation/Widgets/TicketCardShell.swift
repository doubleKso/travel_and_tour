// Port of lib/features/booking/presentation/widgets/ticket_card_shell.dart
import SwiftUI

/// Clips a card into a classic ticket shape: rounded corners with **inward**
/// semicircular notches cut into the left and right edges, positioned
/// `notchFromBottom` points above the bottom — i.e. exactly on the perforation
/// seam that separates the upper and lower sections of the card.
///
/// Because the notch centre is derived from `size.height - notchFromBottom`
/// inside `getClip`, the upper section can be any height and the notches always
/// land on the seam.
struct TicketClipper: Shape {
    /// Distance from the card's bottom edge to the seam (height of the lower
    /// section). The notches are centred here.
    let notchFromBottom: CGFloat
    var notchRadius: CGFloat = 11
    var corner: CGFloat = 18

    init(notchFromBottom: CGFloat, notchRadius: CGFloat = 11, corner: CGFloat = 18) {
        self.notchFromBottom = notchFromBottom
        self.notchRadius = notchRadius
        self.corner = corner
    }

    func path(in rect: CGRect) -> Path {
        getClip(rect.size).offsetBy(dx: rect.minX, dy: rect.minY)
    }

    func getClip(_ size: CGSize) -> Path {
        let w = size.width
        let h = size.height
        let r = notchRadius
        let c = corner
        let ny = h - notchFromBottom // seam / notch centre

        // Traverse clockwise. The two side notches are drawn as pairs of
        // tangent arcs centred on the card's edge, so they bow *into* the card
        // (concave), producing the cut-out look.
        var path = Path()
        path.move(to: CGPoint(x: c, y: 0))
        path.addLine(to: CGPoint(x: w - c, y: 0))
        path.addArc(tangent1End: CGPoint(x: w, y: 0), tangent2End: CGPoint(x: w, y: c), radius: c)
        path.addLine(to: CGPoint(x: w, y: ny - r))
        path.addArc(tangent1End: CGPoint(x: w - r, y: ny - r), tangent2End: CGPoint(x: w - r, y: ny), radius: r)
        path.addArc(tangent1End: CGPoint(x: w - r, y: ny + r), tangent2End: CGPoint(x: w, y: ny + r), radius: r)
        path.addLine(to: CGPoint(x: w, y: h - c))
        path.addArc(tangent1End: CGPoint(x: w, y: h), tangent2End: CGPoint(x: w - c, y: h), radius: c)
        path.addLine(to: CGPoint(x: c, y: h))
        path.addArc(tangent1End: CGPoint(x: 0, y: h), tangent2End: CGPoint(x: 0, y: h - c), radius: c)
        path.addLine(to: CGPoint(x: 0, y: ny + r))
        path.addArc(tangent1End: CGPoint(x: r, y: ny + r), tangent2End: CGPoint(x: r, y: ny), radius: r)
        path.addArc(tangent1End: CGPoint(x: r, y: ny - r), tangent2End: CGPoint(x: 0, y: ny - r), radius: r)
        path.addLine(to: CGPoint(x: 0, y: c))
        path.addArc(tangent1End: CGPoint(x: 0, y: 0), tangent2End: CGPoint(x: c, y: 0), radius: c)
        path.closeSubpath()
        return path
    }
}

/// A white, ticket-shaped card with a `top` section over a fixed-height
/// `bottom` section, separated by a dashed seam that lines up with the inward
/// side notches. The drop shadow follows the notched outline instead of a
/// plain rectangle (Flutter's `PhysicalShape`).
struct TicketCardShell<Top: View, Bottom: View>: View {
    @ViewBuilder let top: () -> Top
    @ViewBuilder let bottom: () -> Bottom
    let bottomHeight: CGFloat
    let selected: Bool
    let onTap: (() -> Void)?
    let margin: EdgeInsets

    init(
        @ViewBuilder top: @escaping () -> Top,
        @ViewBuilder bottom: @escaping () -> Bottom,
        bottomHeight: CGFloat = 46,
        selected: Bool = false,
        onTap: (() -> Void)? = nil,
        margin: EdgeInsets = EdgeInsets(top: 0, leading: 0, bottom: 16, trailing: 0)
    ) {
        self.top = top
        self.bottom = bottom
        self.bottomHeight = bottomHeight
        self.selected = selected
        self.onTap = onTap
        self.margin = margin
    }

    var body: some View {
        let clipper = TicketClipper(notchFromBottom: bottomHeight)
        let elevation: CGFloat = selected ? 12 : 8

        let card = ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                top()
                    .padding(16, 14, 16, 14)
                DashedSeam()
                bottom()
                    .padding(.horizontal, 16)
                    .frame(height: bottomHeight)
            }
            .frame(maxWidth: .infinity)
            .background(AppColors.surface)
            .clipShape(clipper)
            .background {
                // PhysicalShape(elevation: 8/12, shadowColor: black 55%): the
                // Material key + ambient shadows, cast by the notched outline.
                clipper
                    .fill(AppColors.surface)
                    .shadow(color: Colors.black.withValues(alpha: 0.10), radius: elevation * 0.75, x: 0, y: elevation * 0.5)
                    .shadow(color: Colors.black.withValues(alpha: 0.06), radius: elevation * 0.25, x: 0, y: elevation * 0.125)
            }
            // Selected outline traces the same notched path.
            .overlay {
                if selected {
                    clipper.stroke(AppColors.primary, lineWidth: 1.6)
                }
            }

            if selected {
                Icon(Icons.check, size: 14, color: Colors.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(AppColors.primary))
                    .padding(3)
                    .background(Circle().fill(AppColors.surface))
                    .offset(x: 6, y: -6)
            }
        }

        Group {
            // `opaque` makes the entire card bounds tappable (not just the
            // painted children), so selecting a flight works by tapping
            // anywhere on the card — the "Flight Details" trigger sits deeper
            // in the tree and still wins its own region.
            if let onTap {
                card
                    .contentShape(Rectangle())
                    .onTapGesture { onTap() }
            } else {
                card
            }
        }
        // Soft upward-cast shadow defines the card's top edge (Material
        // elevation only shadows downward, so the top otherwise blends into
        // the page).
        .background {
            RoundedRectangle(cornerRadius: 18, style: .circular)
                .fill(Colors.black.withValues(alpha: 0.08))
                .offset(x: 0, y: -3)
                .blur(radius: 12 * 0.57735 + 0.5)
                .allowsHitTesting(false)
        }
        .padding(margin)
    }
}

/// Thin dashed horizontal seam that sits on the notch line.
private struct DashedSeam: View {
    var body: some View {
        GeometryReader { geometry in
            let dash: CGFloat = 6
            let count = max(0, Int((geometry.size.width / (dash * 2)).rounded(.down)))
            // MainAxisAlignment.spaceBetween.
            HStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { index in
                    if index > 0 { Spacer(minLength: 0) }
                    Rectangle()
                        .fill(AppColors.divider)
                        .frame(width: dash, height: 1)
                }
            }
        }
        .frame(height: 1)
        .padding(.horizontal, 16)
    }
}

// ---------------------------------------------------------------------------
// Shared ticket sub-widgets (used by both the search results and history).
// ---------------------------------------------------------------------------

/// Airline logo from the network with a graceful letter-badge fallback.
struct AirlineLogo: View {
    let name: String
    let logoUrl: String
    let carrierCode: String?
    let size: CGFloat

    init(name: String, logoUrl: String, carrierCode: String? = nil, size: CGFloat = 46) {
        self.name = name
        self.logoUrl = logoUrl
        self.carrierCode = carrierCode
        self.size = size
    }

    var body: some View {
        let trimmed = logoUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedLogoUrl = !trimmed.isEmpty
            ? trimmed
            : AppAssets.airlineLogoUrl(name, carrierCode: carrierCode)
        if resolvedLogoUrl.isEmpty {
            LetterBadge(name: name, size: size)
        } else {
            NetworkImage(resolvedLogoUrl, width: size, height: size, fit: .contain) {
                LetterBadge(name: name, size: size)
            } error: {
                LetterBadge(name: name, size: size)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .circular))
        }
    }
}

private struct LetterBadge: View {
    let name: String
    var size: CGFloat = 46

    var body: some View {
        let initial = name.isEmpty ? "?" : String(name.prefix(1)).uppercased()
        Text(initial)
            .textStyle(AppTypography.heading(size * 0.45, color: Colors.white))
            .frame(width: size, height: size)
            .boxDecoration(gradient: AppColors.primaryGradient, radius: 10)
    }
}

/// One end of a route: code (big), city, and time.
struct TicketEndpoint: View {
    let code: String
    let city: String
    let time: String
    let alignEnd: Bool

    init(code: String, city: String, time: String, alignEnd: Bool = false) {
        self.code = code
        self.city = city
        self.time = time
        self.alignEnd = alignEnd
    }

    var body: some View {
        VStack(alignment: alignEnd ? .trailing : .leading, spacing: 0) {
            Text(code).textStyle(AppTypography.heading(22))
            VGap(2)
            Text(city).textStyle(AppTypography.body(11, color: AppColors.textPrimary))
            VGap(4)
            Text(time).textStyle(AppTypography.body(12, weight: .w600, color: AppColors.textPrimary))
        }
    }
}

/// Duration label, a thin line with the travel-mode icon, and the stops label.
struct TicketRouteMiddle: View {
    let isFlight: Bool
    let duration: String
    let stops: String

    init(isFlight: Bool, duration: String, stops: String) {
        self.isFlight = isFlight
        self.duration = duration
        self.stops = stops
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(duration).textStyle(AppTypography.body(11, color: AppColors.textPrimary))
            VGap(4)
            HStack(spacing: 0) {
                dot()
                line().frame(maxWidth: .infinity)
                Icon(isFlight ? Icons.flight : Icons.directions_bus, size: 16, color: AppColors.primary)
                line().frame(maxWidth: .infinity)
                dot()
            }
            VGap(4)
            Text(stops).textStyle(AppTypography.body(11, weight: .w500, color: AppColors.textSecondary))
        }
        .padding(.horizontal, 10)
    }

    private func dot() -> some View {
        Circle()
            .strokeBorder(AppColors.primary, lineWidth: 1.4)
            .frame(width: 5, height: 5)
    }

    private func line() -> some View {
        Rectangle()
            .fill(AppColors.border)
            .frame(height: 1.2)
            .padding(.horizontal, 2)
    }
}

/// Cabin-class pill (filter-badge style) with a distinct colour per class.
struct ClassBadge: View {
    let travelClass: TravelClass

    init(travelClass: TravelClass) {
        self.travelClass = travelClass
    }

    private var color: Color {
        switch travelClass {
        // Teal — deliberately not the brand green so Economy stands apart.
        case .economy: return Color(0xFF0EA5A0)
        // case .premiumEconomy: return AppColors.info
        case .business: return AppColors.accent
        // case .first: return Color(0xFF7E57C2)
        }
    }

    var body: some View {
        let color = self.color
        HStack(spacing: 0) {
            Icon(Icons.airline_seat_recline_normal, size: 14, color: color)
            HGap(6)
            Text(travelClass.label).textStyle(AppTypography.body(11, weight: .w700, color: color))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .boxDecoration(color: color.withValues(alpha: 0.14), radius: 20)
    }
}

/// One flight leg rendered in the "passenger-details ticket" style: the airline
/// row with a Departure / Return badge, then the big IATA codes with a
/// date + route line and departure / arrival times.
///
/// Designed to drop into `TicketCardShell.top`; it carries no outer padding of
/// its own, so the shell's padding sets the margins.
struct FlightLegRow: View {
    let leg: TripOptionModel
    let badge: String
    let badgeColor: Color

    init(leg: TripOptionModel, badge: String, badgeColor: Color) {
        self.leg = leg
        self.badge = badge
        self.badgeColor = badgeColor
    }

    var body: some View {
        let isFlight = leg.mode == .flight
        VStack(alignment: .leading, spacing: 0) {
            // Airline identity + Departure / Return badge.
            HStack(spacing: 0) {
                AirlineLogo(
                    name: leg.operatorName,
                    logoUrl: leg.operatorLogoUrl,
                    carrierCode: leg.carrierCode,
                    size: 20
                )
                HGap(8)
                Text(leg.operatorName)
                    .textStyle(AppTypography.body(12, weight: .w600, color: AppColors.textSecondary))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                LegBadge(label: badge, color: badgeColor)
            }
            VGap(12)
            // Codes + times with a date/route line between.
            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(leg.originCode).textStyle(AppTypography.heading(20))
                    VGap(3)
                    Text(Formatters.time12(leg.departure))
                        .textStyle(AppTypography.body(12, weight: .w600, color: AppColors.textSecondary))
                }
                VStack(spacing: 0) {
                    Text(DateFormat("d-M-yyyy").format(leg.departure))
                        .textStyle(AppTypography.body(11, color: AppColors.textPrimary))
                        .multilineTextAlignment(.center)
                    VGap(4)
                    HStack(spacing: 0) {
                        Circle()
                            .strokeBorder(AppColors.border, lineWidth: 1.5)
                            .frame(width: 6, height: 6)
                        Rectangle()
                            .fill(AppColors.border)
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)
                        if isFlight {
                            Icon(Icons.flight, size: 14, color: AppColors.primary)
                                .rotationEffect(.radians(1.5708))
                        } else {
                            Icon(Icons.directions_bus, size: 14, color: AppColors.primary)
                        }
                        Rectangle()
                            .fill(AppColors.border)
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)
                        Circle()
                            .fill(AppColors.primary)
                            .frame(width: 6, height: 6)
                    }
                    VGap(4)
                    Text(leg.isDirect ? "Non-stop" : "\(leg.stops) stop\(leg.stops > 1 ? "s" : "")")
                        .textStyle(AppTypography.body(11, color: AppColors.textSecondary))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(leg.destinationCode).textStyle(AppTypography.heading(20))
                    VGap(3)
                    Text(Formatters.time12(leg.arrival))
                        .textStyle(AppTypography.body(12, weight: .w600, color: AppColors.textSecondary))
                }
            }
        }
    }
}

/// Small "Departure" / "Return" pill next to the airline name.
private struct LegBadge: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .textStyle(AppTypography.body(11, weight: .w700, color: color))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .boxDecoration(color: color.withValues(alpha: 0.13), radius: 20)
    }
}

// ── Dotted separator ──────────────────────────────────────────────────────────

/// A full-width row of short dashes used to separate sections inside the
/// e-ticket card and the Amount Detail sheet. Shared so both stay identical.
struct DottedLine: View {
    init() {}

    var body: some View {
        GeometryReader { geometry in
            let dotWidth: CGFloat = 4
            let gap: CGFloat = 4
            let count = max(0, Int((geometry.size.width / (dotWidth + gap)).rounded(.down)))
            HStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { _ in
                    Rectangle()
                        .fill(AppColors.border)
                        .frame(width: dotWidth, height: 1.5)
                        .padding(.trailing, gap)
                }
            }
        }
        .frame(height: 1.5)
        .padding(.horizontal, 16)
    }
}
