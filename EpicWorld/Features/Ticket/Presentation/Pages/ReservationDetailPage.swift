// Port of lib/features/ticket/presentation/pages/reservation_detail_page.dart
import SwiftUI

/// Detail for an unpaid **reservation** (a non-MAI flight held but not bought
/// in-app). Shows the held flight + reservation info and points the customer to
/// the office to pay. No e-ticket / QR — that only exists once paid.
struct ReservationDetailPage: View {
    let reservation: TicketModel

    init(reservation: TicketModel) {
        self.reservation = reservation
    }

    @Environment(AppRouter.self) private var router

    private static let gold = Color(0xFFB57A1B)

    var body: some View {
        let r = reservation
        GeometryReader { proxy in
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 0) {
                        // Status banner.
                        HStack(alignment: .top, spacing: 0) {
                            Icon(Icons.bookmark_added_rounded, size: 22, color: AppColors.accent)
                            HGap(12)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(LocaleKeys.ticket_seat_reserved_pending_payment.tr())
                                    .textStyle(AppTypography.body(13.5, weight: .w800, color: Self.gold))
                                VGap(3)
                                Text(LocaleKeys.ticket_visit_or_call_our_office_to.tr())
                                    .textStyle(AppTypography.body(12, color: AppColors.textSecondary, height: 1.4))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(14)
                        .boxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            radius: 16,
                            borderColor: AppColors.accent.withValues(alpha: 0.40)
                        )
                        VGap(16)

                        // The held flight.
                        TripSummaryCard(
                            outbound: r.outbound,
                            inbound: r.inbound,
                            initiallyExpanded: true
                        )
                        VGap(16)

                        // Reservation info.
                        VStack(spacing: 0) {
                            row("Reservation No.", r.bookingReference, valueColor: AppColors.primaryDark)
                            DividerView()
                            row("Airline", r.outbound.operatorName)
                            DividerView()
                            row("Full name", r.passengerName)
                            DividerView()
                            row("Phone number", r.phone ?? "—")
                            DividerView()
                            row("Email", r.email ?? "—")
                            DividerView()
                            row("Booked date", Formatters.fullDate(r.issuedAt))
                            DividerView()
                            VStack(alignment: .leading, spacing: 0) {
                                Text(LocaleKeys.common_message.tr())
                                    .textStyle(AppTypography.body(13, color: AppColors.textSecondary))
                                VGap(6)
                                Text((r.message.map { !$0.isEmpty } ?? false) ? (r.message ?? "") : "—")
                                    .textStyle(AppTypography.body(13, weight: .w700, color: AppColors.textPrimary, height: 1.4))
                            }
                            .padding(.vertical, 12)
                            DividerView()
                            HStack(spacing: 0) {
                                Text(LocaleKeys.ticket_status.tr())
                                    .textStyle(AppTypography.body(13, color: AppColors.textSecondary))
                                Spacer(minLength: 0)
                                Text(LocaleKeys.common_booked.tr())
                                    .textStyle(AppTypography.body(11.5, weight: .w800, color: Self.gold))
                                    .padding(horizontal: 10, vertical: 4)
                                    .boxDecoration(color: AppColors.accent.withValues(alpha: 0.14), radius: 20)
                            }
                            .padding(.vertical, 12)
                        }
                        .padding(16, 6, 16, 6)
                        .frame(maxWidth: .infinity)
                        .boxDecoration(color: AppColors.surface, radius: 18, borderColor: AppColors.border)
                    }
                    .padding(AppSpacing.screenH, 16, AppSpacing.screenH, 24)
                }
                .frame(maxHeight: .infinity)
                bottomBar(bottomInset: proxy.safeAreaInsets.bottom)
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .background(AppColors.background.ignoresSafeArea())
    }

    private var header: some View {
        HStack(spacing: 0) {
            Button {
                Task { await router.maybePop() }
            } label: {
                Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            Text(LocaleKeys.ticket_reservation_details.tr())
                .textStyle(AppTypography.heading(18, color: Colors.white))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            // No phone action here — "Call to Confirm" already lives in the
            // bottom bar, so the header stays uncluttered.
            HGap(44)
        }
        .padding(4, 6, 6, 14)
        .frame(maxWidth: .infinity)
        .background(AppColors.heroGradient.ignoresSafeArea(edges: .top))
    }

    private func bottomBar(bottomInset: CGFloat) -> some View {
        HStack(spacing: 0) {
            Button {
                callUs()
            } label: {
                HStack(spacing: 0) {
                    Icon(Icons.phone_rounded, size: 18)
                    HGap(8)
                    Text(LocaleKeys.ticket_call_to_confirm.tr())
                        .textStyle(AppTypography.body(13, weight: .w700))
                }
            }
            .buttonStyle(OutlinedButtonStyle(
                foregroundColor: AppColors.primary,
                borderColor: AppColors.primary,
                cornerRadius: 12,
                padding: EdgeInsets(top: 13, leading: 0, bottom: 13, trailing: 0)
            ))
            .frame(maxWidth: .infinity)
            HGap(12)
            Button {
                router.popUntilRoot()
            } label: {
                Text(LocaleKeys.common_back_to_home.tr())
                    .textStyle(AppTypography.body(13, weight: .w700, color: Colors.white))
            }
            .buttonStyle(ElevatedButtonStyle(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                cornerRadius: 12,
                padding: EdgeInsets(top: 14, leading: 0, bottom: 14, trailing: 0)
            ))
            .frame(maxWidth: .infinity)
        }
        .padding(16, 12, 16, bottomInset > 0 ? bottomInset - 8 : 12)
        .frame(maxWidth: .infinity)
        .background(
            Color.clear.boxDecoration(
                color: AppColors.surface,
                shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 16, offset: Offset(0, -4))]
            )
        )
    }

    private func callUs() {
        Task { await ContactLauncher.dial(AppConsts.hotlinePhone) }
    }

    private func row(_ label: String, _ value: String, valueColor: Color? = nil) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(label)
                .textStyle(AppTypography.body(13, color: AppColors.textSecondary))
            HGap(12)
            Text(value)
                .textStyle(AppTypography.body(13, weight: .w700, color: valueColor ?? AppColors.textPrimary))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 12)
    }
}

private struct DividerView: View {
    var body: some View {
        MaterialDivider(height: 1, color: AppColors.dividerLight)
    }
}
