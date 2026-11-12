// Port of lib/features/booking/presentation/pages/booking_completed_page.dart
import SwiftUI
import UIKit

struct BookingCompletedPage: View {
    let ticket: TicketModel

    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router
    @Environment(\.routeEntryID) private var entryID

    @State private var pdfBusy = false

    init(ticket: TicketModel) {
        self.ticket = ticket
    }

    /// Dart `mounted`: this route is still on the stack.
    private var mounted: Bool {
        guard let entryID else { return true }
        return router.entries.contains { $0.id == entryID }
    }

    var body: some View {
        let booking = container.flightBookingBloc.state

        Scaffold(
            backgroundColor: AppColors.background,
            appBar: { EmptyView() },
            bottomNavigationBar: { buildBottomBar(booking) }
        ) {
            VStack(spacing: 0) {
                CheckoutStepHeader(
                    stage: booking.stage,
                    title: LocaleKeys.booking_booking_confirmed.tr(),
                    showBack: false
                )
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        buildETicketHeaderRow()
                        VGap(10)
                        // Dart wraps this in a RepaintBoundary keyed for the
                        // gallery export; the save button renders the same card.
                        ETicketCard(ticket: ticket)
                        if ETicketGalleryImage.isSupportedPlatform {
                            VGap(12)
                            ETicketGallerySaveButton(ticket: ticket)
                        }
                        VGap(20)
                    }
                    .padding(AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.screenH)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .popScope(canPop: false)
    }

    // ── E-Ticket header row (label + Download PDF) ────────────────────────────

    private func buildETicketHeaderRow() -> some View {
        HStack(spacing: 0) {
            Text(LocaleKeys.booking_e_ticket.tr())
                .textStyle(AppTypography.heading(16, color: AppColors.textPrimary))
            Spacer(minLength: 0)
            Button {
                Task { await downloadPdf() }
            } label: {
                HStack(spacing: 0) {
                    if pdfBusy {
                        ProgressSpinner(size: 12, color: Colors.white)
                    } else {
                        Icon(Icons.download_rounded, size: 13, color: Colors.white)
                    }
                    HGap(8)
                    Text(LocaleKeys.common_download_pdf.tr())
                        .textStyle(AppTypography.body(11, weight: .w600, color: Colors.white))
                }
            }
            .buttonStyle(ElevatedButtonStyle(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                minimumHeight: 0,
                fullWidth: false,
                cornerRadius: 30,
                padding: EdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 10)
            ))
            .disabled(pdfBusy)
        }
    }

    // ── Bottom bar ────────────────────────────────────────────────────────────

    private func buildBottomBar(_ booking: FlightBookingState) -> some View {
        let bottomInset = BookingCompletedPage.safeAreaBottom
        return HStack(spacing: 0) {
            // View Amount Detail — opens the amount-summary sheet.
            Button {
                showAmountDetail(booking)
            } label: {
                HStack(spacing: 0) {
                    Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.primary)
                    HGap(8)
                    Text(LocaleKeys.booking_amount_detail.tr())
                        .textStyle(AppTypography.body(13, weight: .w700, color: AppColors.primary))
                }
            }
            .buttonStyle(OutlinedButtonStyle(
                foregroundColor: AppColors.primary,
                borderColor: AppColors.primary,
                cornerRadius: 12,
                padding: EdgeInsets(top: 14, leading: 0, bottom: 14, trailing: 0)
            ))
            .frame(maxWidth: .infinity)
            HGap(10)
            // Back to Home
            Button {
                container.flightBookingBloc.add(.bookingReset)
                router.popUntilRoot()
            } label: {
                HStack(spacing: 0) {
                    Icon(Icons.home_rounded, size: 18, color: Colors.white)
                    HGap(8)
                    Text(LocaleKeys.common_back_to_home.tr())
                        .textStyle(AppTypography.body(13, weight: .w700, color: Colors.white))
                }
            }
            .buttonStyle(ElevatedButtonStyle(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                cornerRadius: 12,
                padding: EdgeInsets(top: 14, leading: 0, bottom: 14, trailing: 0)
            ))
            .frame(maxWidth: .infinity)
        }
        // EdgeInsets.fromLTRB(16, 12, 16, bottomInset > 0 ? bottomInset - 8 : 4),
        // measured from the screen edge: the bar already sits above the home
        // indicator, so only the -8 overlap remains.
        .padding(EdgeInsets(top: 12, leading: 16, bottom: bottomInset > 0 ? -8 : 4, trailing: 16))
        .background(BottomBarBackground())
    }

    // Builds the e-ticket PDF and downloads / shares it. The PDF is drawn as a
    // full-width A4 document (see `ETicketPdf.build`) so it prints as proper A4
    // pages rather than one long mobile-shaped strip. The download tries the
    // most compatible path, so a failure is reported clearly.
    private func downloadPdf() async {
        pdfBusy = true
        defer {
            if mounted { pdfBusy = false }
        }
        // Give the button's spinner a frame to paint before the (heavy) build
        // work starts, so the tap feels instant instead of frozen.
        try? await Task.sleep(for: .milliseconds(16))
        // The native `ETicketPdf.build` cannot throw, so the only failure left
        // to report is the device refusing both the share sheet and printing.
        let bytes = await ETicketPdf.build(ticket)
        let filename = ETicketPdf.fileName(ticket)

        // The web-only blob download (`kIsWeb`) has no iOS equivalent.

        // Native share / save sheet.
        if SharePresenter.sharePdf(bytes, filename: filename) { return }
        // Fallback: open the print / "Save as PDF" dialog straight from the
        // bytes (`Printing.layoutPdf`).
        if BookingCompletedPage.layoutPdf(bytes, name: filename) { return }
        let error = StateError("The PDF could not be shared or printed.")
        SnackBarCenter.shared.show(
            LocaleKeys.common_could_not_download_pdf.tr(args: ["\(error)"]),
            backgroundColor: AppColors.error,
            floating: true
        )
    }

    /// `Printing.layoutPdf(name:, onLayout: (_) async => bytes)`. False when
    /// the print sheet could not be shown.
    @MainActor
    private static func layoutPdf(_ bytes: Data, name: String) -> Bool {
        guard UIPrintInteractionController.isPrintingAvailable else { return false }
        let info = UIPrintInfo(dictionary: nil)
        info.jobName = name
        info.outputType = .general
        let controller = UIPrintInteractionController.shared
        controller.printInfo = info
        controller.printingItem = bytes
        return controller.present(animated: true, completionHandler: nil)
    }

    // Opens the amount-summary sheet, sliding up from the bottom (same style as
    // the flight-details sheet on the Select Departure page).
    private func showAmountDetail(_ booking: FlightBookingState) {
        let total = ticket.totalPaid
        let discount = ticket.discount
        let promoCode = ticket.promoCode
        let adults = booking.travellerCount
        Task {
            let _: Void? = await showModalBottomSheet(
                isScrollControlled: true,
                backgroundColor: Colors.transparent
            ) { _ in
                AmountDetailSheet(total: total, discount: discount, promoCode: promoCode, adults: adults)
            }
        }
    }

    /// `MediaQuery.of(context).padding.bottom`.
    @MainActor
    fileprivate static var safeAreaBottom: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
        return window?.safeAreaInsets.bottom ?? 0
    }
}

// ── Amount detail bottom sheet ────────────────────────────────────────────────

extension BookingCompletedPage {
    /// Slide-up sheet mirroring the Payment page's Amount Summary card. The fare
    /// is rebuilt from the paid total plus the checkout discount, so the lines
    /// always add back up to what was charged.
    ///
    /// Nested (rather than file-private) so the unit tests can check the
    /// figures it prints.
    struct AmountDetailSheet: View {
        let total: Double
        let discount: Double

        /// Empty when no promo code was used, which shows as a dash.
        let promoCode: String
        let adults: Int

        @Environment(\.dismissModal) private var dismissModal

        init(total: Double, discount: Double, promoCode: String, adults: Int) {
            self.total = total
            self.discount = discount
            self.promoCode = promoCode
            self.adults = adults
        }

        var subTotal: Int { Int((total + discount).rounded()) }
        var subTotalValue: String { Formatters.price(Double(subTotal)) }
        var discountValue: String { "− \(Formatters.price(discount))" }
        var promoValue: String { promoCode.isEmpty ? "-" : promoCode }
        var grandTotalValue: String { Formatters.price(total) }

        var body: some View {
            VStack(spacing: 0) {
                VGap(10)
                // Drag handle.
                RoundedRectangle(cornerRadius: 2, style: .circular)
                    .fill(AppColors.border)
                    .frame(width: 42, height: 4)
                // Heading + close button.
                HStack(spacing: 0) {
                    Text(LocaleKeys.booking_amount_summary.tr())
                        .textStyle(AppTypography.heading(20))
                    Spacer(minLength: 0)
                    Icon(Icons.close, size: 18, color: AppColors.textSecondary)
                        .padding(5)
                        .boxDecoration(color: AppColors.background, circle: true)
                        .onTapGesture { dismissModal() }
                }
                .padding(20, 14, 12, 4)
                VStack(spacing: 0) {
                    AmountLine(
                        label: LocaleKeys.booking_adult_s.tr(args: ["\(adults)"]),
                        value: subTotalValue
                    )
                    VGap(16)
                    AmountLine(label: LocaleKeys.booking_sub_total.tr(), value: subTotalValue)
                    VGap(16)
                    AmountLine(label: LocaleKeys.booking_discount.tr(), value: discountValue)
                    VGap(16)
                    AmountLine(label: LocaleKeys.booking_promo.tr(), value: promoValue)
                    DottedLine()
                        .padding(.vertical, 16)
                    AmountLine(
                        label: LocaleKeys.common_grand_total.tr(),
                        value: grandTotalValue,
                        grand: true
                    )
                }
                .padding(20, 6, 20, 20)
            }
            .frame(maxWidth: .infinity)
            .background(
                UnevenRoundedRectangle(cornerRadii: BorderRadius.vertical(top: 28), style: .circular)
                    .fill(AppColors.surface)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }
}

/// One label ↔ value line inside the amount sheet. The `grand` total gets a
/// larger label and a bigger, primary-coloured price.
private struct AmountLine: View {
    let label: String
    let value: String
    var grand = false

    var body: some View {
        if grand {
            HStack(spacing: 0) {
                Text(label)
                    .textStyle(AppTypography.body(15.5, weight: .w700, color: AppColors.textPrimary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                HGap(12)
                Text(value)
                    .textStyle(AppTypography.heading(19, color: AppColors.primary))
            }
        } else {
            let style = AppTypography.body(13.5, weight: .w500, color: AppColors.textSecondary)
            HStack(spacing: 0) {
                Text(label)
                    .textStyle(style)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HGap(12)
                Text(value).textStyle(style)
            }
        }
    }
}

/// The bottom bar's white surface with its upward shadow
/// (`BoxShadow(black 12%, blur 16, offset (0, -4))`), running under the home
/// indicator like Flutter's `bottomNavigationBar`.
private struct BottomBarBackground: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Colors.black.withValues(alpha: 0.12))
                .offset(x: 0, y: -4)
                .blur(radius: 16 * 0.57735 + 0.5)
            Rectangle()
                .fill(AppColors.surface)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea(edges: .bottom)
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
