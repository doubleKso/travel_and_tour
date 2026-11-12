// Port of lib/features/home/presentation/pages/commercial_flight_page.dart

import SwiftUI

/// COMMERCIAL FLIGHT SCHEDULE — a read-only timetable of partner-airline
/// commercial flights, reached from the "Commercial flights" card on the
/// Version 2 home. The cards show a schedule's API price and hand non-bookable
/// commercial flights to the existing service-enquiry form.
struct CommercialFlightPage: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router

    /// `_searchC` + `_query` (the controller's text is the query).
    @State private var query = ""

    init() {}

    private func filtered(_ schedules: [FlightScheduleModel]) -> [FlightScheduleModel] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return schedules }
        return schedules.filter { f in
            f.airlineName.lowercased().contains(q)
                || f.airlineCode.lowercased().contains(q)
                || f.fromCity.lowercased().contains(q)
                || f.toCity.lowercased().contains(q)
        }
    }

    /// `{for (final carrier in carriers) if (code.isNotEmpty) code.toUpperCase(): carrier}`.
    private func carriersByCode(_ carriers: [FlightCarrierModel]) -> [String: FlightCarrierModel] {
        var byCode: [String: FlightCarrierModel] = [:]
        for carrier in carriers {
            let code = carrier.code.trimmingCharacters(in: .whitespacesAndNewlines)
            if !code.isEmpty { byCode[code.uppercased()] = carrier }
        }
        return byCode
    }

    var body: some View {
        let scheduleState = container.activeFlightScheduleList.state
        let carriers = container.activeFlightCarrierList.state.valueOrNull ?? []
        let carriersByCode = self.carriersByCode(carriers)
        let filtered = self.filtered(scheduleState.valueOrNull ?? [])

        GeometryReader { proxy in
            VStack(spacing: 0) {
                // Green header — matches the ticket-choose page header.
                header(topPad: proxy.safeAreaInsets.top)
                ScrollView {
                    VStack(spacing: 0) {
                        // Full-width banner with the airline search box overlapping it.
                        CoverAssetImage(path: AppAssets.hotelSample, fallback: AppColors.primarySurface)
                            .frame(height: 150)
                            .frame(maxWidth: .infinity)
                            .overlay(alignment: .bottom) {
                                searchBox
                                    .padding(.horizontal, 16)
                                    .offset(y: 26)
                            }
                            .zIndex(1)
                        VGap(40)
                        HStack(spacing: 0) {
                            Text(LocaleKeys.home_flight_timetable.tr())
                                .textStyle(AppTypography.heading(16, color: AppColors.textPrimary))
                            Spacer(minLength: 0)
                            HStack(spacing: 0) {
                                Icon(Icons.event_rounded, size: 13, color: Color(0xFFB57A1B))
                                HGap(5)
                                Text(Formatters.monthYear(DateTime.now()))
                                    .textStyle(AppTypography.body(11.5, weight: .w800, color: Color(0xFFB57A1B)))
                            }
                            .padding(horizontal: 10, vertical: 5)
                            .boxDecoration(color: AppColors.accent.withValues(alpha: 0.14), radius: 30)
                        }
                        .padding(16, 0, 16, 12)
                        if scheduleState.isLoading {
                            ProgressView()
                                .tint(AppColors.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 48)
                        } else if scheduleState.hasError {
                            Text("Unable to load flight schedules.")
                                .textStyle(AppTypography.body(14, color: AppColors.textSecondary))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 48)
                        } else if filtered.isEmpty {
                            VStack(spacing: 0) {
                                Icon(Icons.search_off_rounded, size: 40, color: AppColors.textTertiary)
                                VGap(12)
                                Text(LocaleKeys.home_no_flights_match.tr(
                                    args: [query.trimmingCharacters(in: .whitespacesAndNewlines)]
                                ))
                                .textStyle(AppTypography.body(14, weight: .w600, color: AppColors.textSecondary))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                        } else {
                            ForEach(Array(filtered.enumerated()), id: \.offset) { _, f in
                                let carrier = carriersByCode[f.airlineCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()]
                                ScheduleCard(
                                    flight: f,
                                    carrierName: carrier?.name ?? "",
                                    logoUrl: carrier?.logoUrl ?? "",
                                    onEnquire: {
                                        let departureDate = f.nextOperatingDate()
                                        container.flightBookingBloc.add(
                                            .commercialFlightEnquiryStarted(
                                                f.toTripOption(
                                                    departureDate,
                                                    carrierLogoUrl: carrier?.logoUrl,
                                                    carrierName: carrier?.name
                                                )
                                            )
                                        )
                                        router.push(.bookingDetail)
                                    }
                                )
                                .padding(.horizontal, 16)
                            }
                        }
                        VGap(12)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .background(AppColors.background.ignoresSafeArea())
    }

    private func header(topPad: CGFloat) -> some View {
        HStack(spacing: 0) {
            Button {
                Task { await router.maybePop() }
            } label: {
                Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            Text(LocaleKeys.home_commercial_flight_schedule.tr())
                .textStyle(AppTypography.heading(18, color: Colors.white))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                Task { await ContactLauncher.dial(AppConsts.hotlinePhone) }
            } label: {
                Icon(Icons.phone_outlined, color: Colors.white)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
        }
        .padding(4, topPad + 6, 6, 14)
        .frame(maxWidth: .infinity)
        .background(AppColors.heroGradient)
    }

    private var searchBox: some View {
        HStack(spacing: 0) {
            Icon(Icons.search_rounded, size: 20, color: AppColors.textTertiary)
            HGap(10)
            TextField(
                "",
                text: $query,
                prompt: Text(LocaleKeys.home_search_for_airline.tr())
                    .font(AppTypography.body(13.5).font)
                    .foregroundColor(AppColors.textTertiary)
            )
            .font(AppTypography.body(14, weight: .w500).font)
            .foregroundStyle(AppColors.textPrimary)
            .tint(AppColors.primary)
            .autocorrectionDisabled()
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            if !query.isEmpty {
                Icon(Icons.close_rounded, size: 18, color: AppColors.textTertiary)
                    .contentShape(Rectangle())
                    .onTapGesture { query = "" }
            }
        }
        .padding(.horizontal, 14)
        .boxDecoration(
            color: AppColors.surface,
            radius: 14,
            shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: Offset(0, 6))]
        )
    }
}

/// `Image.asset(path, fit: BoxFit.cover)` filling the space it is given, with
/// the `errorBuilder` colour when the asset is missing.
private struct CoverAssetImage: View {
    let path: String
    let fallback: Color

    var body: some View {
        Color.clear
            .overlay {
                if AppImage.image(for: path) != nil {
                    AppImage(path, fit: .cover)
                } else {
                    fallback
                }
            }
            .clipped()
    }
}

// ---------------------------------------------------------------------------
// Schedule card (air-ticket result styling, read-only)
// ---------------------------------------------------------------------------

private struct ScheduleCard: View {
    let flight: FlightScheduleModel
    let carrierName: String
    let logoUrl: String
    let onEnquire: () -> Void

    private var airlineName: String {
        let trimmed = carrierName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? flight.airlineName : trimmed
    }

    private var airlineLabel: String {
        let flightNumber = flight.flightNo.trimmingCharacters(in: .whitespacesAndNewlines)
        return flightNumber.isEmpty ? airlineName : "\(airlineName), \(flightNumber)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Airline row.
            HStack(spacing: 0) {
                AirlineLogo(name: airlineName, logoUrl: logoUrl, carrierCode: flight.airlineCode, size: 30)
                HGap(10)
                Text(airlineLabel)
                    .textStyle(AppTypography.body(13.5, weight: .w700, color: AppColors.textPrimary))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            VGap(12)
            DottedDivider()
            VGap(12)
            // Route: departure — plane line — arrival.
            HStack(alignment: .center, spacing: 0) {
                Endpoint(
                    time: Formatters.scheduleTime12(flight.departTime),
                    place: "\(flight.fromCode) · \(flight.fromCity)"
                )
                PlaneLine()
                    .frame(maxWidth: .infinity)
                Endpoint(
                    time: Formatters.scheduleTime12(flight.arriveTime),
                    place: "\(flight.toCode) · \(flight.toCity)",
                    alignEnd: true
                )
            }
            VGap(12)
            // Frequency, API fare, and direct entry to the enquiry form.
            HStack(spacing: 0) {
                Icon(Icons.event_available_rounded, size: 15, color: AppColors.primary)
                HGap(6)
                // Keep the complete API fare visible next to the frequency.
                // On narrow devices this row gently scales down rather than
                // replacing the currency suffix with an ellipsis.
                HStack(spacing: 0) {
                    Text(flight.daysOfWeek)
                        .textStyle(AppTypography.body(12.5, weight: .w700, color: AppColors.primaryDark))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    HGap(6)
                    Text(
                        flight.indicativeFare > 0
                            ? "from ~\(Formatters.price(flight.indicativeFare, flight.currency))"
                            : "Price on enquiry"
                    )
                    .textStyle(AppTypography.body(12, weight: .w700, color: AppColors.textSecondary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HGap(12)
                Button(action: onEnquire) {
                    Text("Enquire")
                        .textStyle(AppTypography.body(12.5, weight: .w800, color: Colors.white))
                }
                .buttonStyle(ElevatedButtonStyle(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumHeight: 38,
                    fullWidth: false,
                    cornerRadius: 12,
                    padding: EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
                ))
            }
        }
        .padding(16, 14, 16, 14)
        .boxDecoration(
            color: AppColors.surface,
            radius: 20,
            borderColor: Color(0xFFECEEF3),
            shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: Offset(0, 4))]
        )
        .padding(.bottom, 12)
    }
}

/// One route endpoint: a big time with the code · city beneath it.
private struct Endpoint: View {
    let time: String
    let place: String
    var alignEnd = false

    var body: some View {
        VStack(alignment: alignEnd ? .trailing : .leading, spacing: 0) {
            Text(time)
                .textStyle(AppTypography.heading(21, weight: .w800, color: AppColors.textPrimary))
            VGap(3)
            Text(place)
                .textStyle(AppTypography.body(11.5, color: AppColors.textPrimary))
        }
    }
}

/// A thin dashed line with a plane icon in the middle (points right).
private struct PlaneLine: View {
    var body: some View {
        HStack(spacing: 0) {
            dot()
            Dashes(maxCount: 60)
                .frame(maxWidth: .infinity)
            Icon(Icons.flight, size: 16, color: AppColors.primary)
                .rotationEffect(.radians(1.5708))
            Dashes(maxCount: 60)
                .frame(maxWidth: .infinity)
            dot()
        }
        .padding(.horizontal, 10)
    }

    private func dot() -> some View {
        Circle()
            .stroke(Color(0xFFC9CDD6), lineWidth: 1.4)
            .padding(0.7)
            .frame(width: 5, height: 5)
    }
}

/// `count = (width / (dash + gap)).floor().clamp(0, maxCount)` dashes spread
/// edge to edge (`MainAxisAlignment.spaceBetween`).
private struct Dashes: View {
    let maxCount: Int

    var body: some View {
        GeometryReader { proxy in
            let dash: CGFloat = 3
            let gap: CGFloat = 4
            let count = min(max(Int((proxy.size.width / (dash + gap)).rounded(.down)), 0), maxCount)
            HStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { i in
                    if i > 0 { Spacer(minLength: 0) }
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(0xFFC9CDD6))
                        .frame(width: dash, height: 1.5)
                }
            }
            .frame(width: proxy.size.width, alignment: .leading)
        }
        .frame(height: 1.5)
    }
}

/// A thin full-width dotted separator between the card's sections.
private struct DottedDivider: View {
    var body: some View {
        Dashes(maxCount: 200)
    }
}
