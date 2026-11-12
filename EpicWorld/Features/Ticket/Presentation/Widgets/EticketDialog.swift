// Port of lib/features/ticket/presentation/widgets/eticket_dialog.dart
import SwiftUI

/// Displays the app's standard, scrollable e-ticket document in a modal.
@MainActor
func showETicketDialog(_ ticket: TicketModel) async {
    let _: Void? = await showDialog(barrierColor: Colors.black.withValues(alpha: 0.6)) { dismiss in
        ETicketDialog(ticket: ticket, onClose: { dismiss(nil) })
    }
}

private struct ETicketDialog: View {
    let ticket: TicketModel
    let onClose: () -> Void

    init(ticket: TicketModel, onClose: @escaping () -> Void) {
        self.ticket = ticket
        self.onClose = onClose
    }

    /// The card's Important Information state, shared with the gallery capture
    /// so the saved image matches what is on screen (the Dart
    /// `RepaintBoundary` captures the live card).
    @State private var importantInfoOpen = false

    var body: some View {
        // Dialog(insetPadding: symmetric(horizontal: 14, vertical: 40)). The modal
        // host already insets dialogs by 40 / 24 (the Material default), so the
        // difference is applied here.
        VStack(alignment: .trailing, spacing: 0) {
            Button(action: onClose) {
                Icon(Icons.close_rounded, size: 20, color: AppColors.textPrimary)
                    .padding(4)
                    .background(Circle().fill(Colors.white))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 8)

            ScrollView {
                ETicketCard(
                    ticket: ticket,
                    showPaymentSummary: true,
                    importantInfoOpen: $importantInfoOpen
                )
            }
            .scrollBounceBehavior(.basedOnSize)
            .clipShape(RoundedRectangle(cornerRadius: 20))

            if ETicketGalleryImage.isSupportedPlatform {
                VGap(12)
                ETicketGallerySaveButton(ticket: ticket) {
                    ETicketCard(
                        ticket: ticket,
                        importantInfoAlwaysOpen: importantInfoOpen,
                        showPaymentSummary: true
                    )
                }
            }
        }
        .padding(.horizontal, 14 - 40)
        .padding(.vertical, 40 - 24)
    }
}
