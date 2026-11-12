// Port of lib/features/ticket/presentation/widgets/eticket_gallery_save_button.dart
import SwiftUI
import Photos
import UIKit

/// Saves a rendered e-ticket image in the customer's device gallery.
///
/// The shared `ETicketCard` is rendered off-screen (`ImageRenderer`, the
/// counterpart of Dart's `RepaintBoundary`) instead of a screenshot of the
/// screen, so the saved image contains the complete ticket, even when the
/// ticket itself is taller than the visible scroll area.
///
/// Dart passes the `GlobalKey` of the `RepaintBoundary` wrapping the card; here
/// the button is given what to capture instead: by default the
/// `ETicketCard(ticket:showPaymentSummary:)` it sits under, or any view through
/// `capture:`. It is captured at this button's own width, which is the width
/// of the column the card is laid out in.
struct ETicketGallerySaveButton: View {
    let ticket: TicketModel
    private let capture: () -> AnyView

    /// Captures `ETicketCard(ticket: ticket, showPaymentSummary: showPaymentSummary)`.
    init(ticket: TicketModel, showPaymentSummary: Bool = false) {
        self.ticket = ticket
        self.capture = {
            AnyView(ETicketCard(ticket: ticket, showPaymentSummary: showPaymentSummary))
        }
    }

    /// Captures the view `capture` builds (the Dart `RepaintBoundary` child).
    init<Content: View>(ticket: TicketModel, @ViewBuilder capture: @escaping () -> Content) {
        self.ticket = ticket
        self.capture = { AnyView(capture()) }
    }

    @State private var isSaving = false
    @State private var width: CGFloat = 0

    var body: some View {
        if !ETicketGalleryImage.isSupportedPlatform {
            EmptyView()
        } else {
            Button {
                Task { await saveToGallery() }
            } label: {
                HStack(spacing: 0) {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Colors.white)
                            .controlSize(.small)
                            .frame(width: 18, height: 18)
                    } else {
                        Icon(Icons.add_photo_alternate_outlined, size: 19)
                    }
                    HGap(8)
                    Text(LocaleKeys.common_save_to_gallery.tr())
                        .textStyle(AppTypography.body(13, weight: .w700, color: Colors.white))
                }
            }
            .buttonStyle(ElevatedButtonStyle(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primaryDark.withValues(alpha: 0.6),
                disabledForegroundColor: Colors.white,
                minimumHeight: 48,
                cornerRadius: 12,
                padding: EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
            ))
            .disabled(isSaving)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { width = proxy.size.width }
                        .onChange(of: proxy.size.width) { _, newWidth in width = newWidth }
                }
            )
        }
    }

    private func saveToGallery() async {
        isSaving = true
        do {
            try await ETicketGalleryImage.save(
                content: capture(),
                width: width,
                ticket: ticket
            )
            if Task.isCancelled { isSaving = false; return }
            showMessage(LocaleKeys.common_e_ticket_saved_to_gallery.tr())
        } catch {
            if !Task.isCancelled {
                showMessage(
                    LocaleKeys.common_could_not_save_to_gallery.tr(args: ["\(error)"]),
                    isError: true
                )
            }
        }
        isSaving = false
    }

    private func showMessage(_ message: String, isError: Bool = false) {
        SnackBarCenter.shared.show(
            message,
            backgroundColor: isError ? AppColors.error : AppColors.success,
            floating: true
        )
    }
}

/// Encodes a rendered e-ticket and saves it to the device photo library. Kept
/// separate from the button so every e-ticket entry point uses the exact same
/// export rules and filename.
@MainActor
enum ETicketGalleryImage {
    private static let maxImageDimension: CGFloat = 8192.0

    /// Android and iOS in Dart; this build only runs on iOS (the web branch has
    /// no iOS counterpart).
    static var isSupportedPlatform: Bool { true }

    static func save<Content: View>(
        content: Content,
        width: CGFloat,
        ticket: TicketModel
    ) async throws {
        // Android's storage permission request has no iOS counterpart; the
        // add-only photo permission is asked for when saving, below.
        let renderer = ImageRenderer(content: content.environment(\.locale, L10n.locale))
        renderer.proposedSize = ProposedViewSize(width: width > 0 ? width : nil, height: nil)

        var size = CGSize.zero
        renderer.render { renderedSize, _ in size = renderedSize }
        guard size.width > 0, size.height > 0 else {
            throw StateError("The e-ticket is not ready to save yet.")
        }

        // Three device pixels per logical pixel keeps text crisp. Long tickets are
        // scaled just enough to remain below common GPU image-dimension limits.
        let longestSide = max(size.width, size.height)
        renderer.scale = min(3.0, maxImageDimension / longestSide)
        guard let image = renderer.uiImage, let data = image.pngData() else {
            throw StateError("The e-ticket image could not be encoded.")
        }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw StateError("The gallery did not accept the e-ticket image.")
        }
        let filename = "\(fileName(ticket)).png"
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let options = PHAssetResourceCreationOptions()
                options.originalFilename = filename
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: options)
            }
        } catch {
            throw StateError("The gallery did not accept the e-ticket image.")
        }
    }

    nonisolated static func fileName(_ ticket: TicketModel) -> String {
        let trimmedReference = ticket.bookingReference.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawReference = !trimmedReference.isEmpty
            ? trimmedReference
            : ticket.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let reference = rawReference.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "_", options: .regularExpression)
        return "epic_world_eticket_\(reference.isEmpty ? "ticket" : reference)"
    }
}
