// Port of lib/features/profile/presentation/widgets/logout_confirmation_dialog.dart
import SwiftUI

@MainActor
func showLogoutConfirmationDialog() async -> Bool {
    let confirmed: Bool? = await showDialog(barrierDismissible: true) { _ in
        LogoutConfirmationDialog()
    }
    return confirmed ?? false
}

/// Profile logout confirmation matching the compact two-action design.
struct LogoutConfirmationDialog: View {
    init() {}

    // private static let actionBlue = AppColors.info
    private static let actionConfirm = AppColors.primary

    /// `Navigator.of(context).pop(value)`.
    @Environment(\.dismissModal) private var dismissModal

    var body: some View {
        VStack(spacing: 0) {
            Icon(Icons.logout_rounded, size: 30, color: AppColors.accent)
                .frame(width: 56, height: 56)
                .boxDecoration(circle: true, borderColor: AppColors.accent, borderWidth: 2)
            VGap(16)
            Text(LocaleKeys.profile_logout_confirmation_title.tr())
                .textStyle(AppTypography.heading(15, weight: .w700, color: AppColors.headerDark))
                .multilineTextAlignment(.center)
            VGap(17)
            Text(LocaleKeys.profile_logout_confirmation_message.tr())
                .textStyle(AppTypography.body(13, weight: .w600, color: AppColors.textPrimary, height: 1.35))
                .multilineTextAlignment(.center)
            VGap(22)
            HStack(spacing: 0) {
                Button {
                    dismissModal(false)
                } label: {
                    Text(LocaleKeys.common_cancel.tr())
                        .textStyle(AppTypography.body(14, weight: .w600, color: LogoutConfirmationDialog.actionConfirm))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .buttonStyle(OutlinedButtonStyle(
                    foregroundColor: LogoutConfirmationDialog.actionConfirm,
                    borderColor: LogoutConfirmationDialog.actionConfirm,
                    minimumHeight: 40,
                    cornerRadius: 6
                ))
                .frame(height: 40)
                .frame(maxWidth: .infinity)
                HGap(10)
                Button {
                    dismissModal(true)
                } label: {
                    Text(LocaleKeys.profile_log_out.tr())
                        .textStyle(AppTypography.body(14, weight: .w600, color: Colors.white))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .buttonStyle(ElevatedButtonStyle(
                    backgroundColor: LogoutConfirmationDialog.actionConfirm,
                    foregroundColor: Colors.white,
                    minimumHeight: 40,
                    cornerRadius: 6,
                    elevation: 1
                ))
                .frame(height: 40)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16, 17, 16, 15)
        .frame(maxWidth: 340)
        // Dialog(shape: radius 10, elevation: 12, shadowColor: black @ 24%).
        .boxDecoration(
            color: AppColors.surface,
            radius: 10,
            shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.24), blurRadius: 12, offset: Offset(0, 6))]
        )
        // `insetPadding: EdgeInsets.symmetric(horizontal: 28)` — `ModalHost`
        // insets every dialog by Material's default 40, so give 12 back.
        .padding(.horizontal, -12)
    }
}
