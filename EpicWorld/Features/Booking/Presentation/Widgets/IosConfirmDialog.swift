// Port of lib/features/booking/presentation/widgets/ios_confirm_dialog.dart
import SwiftUI

/// iOS-style confirmation with the two choices always on one row.
///
/// [CupertinoAlertDialog] is not used because it silently drops to a stacked
/// column once the labels stop fitting side by side, which Myanmar's longer
/// words do — the row here holds in every language.
///
/// Present it with `showDialog(barrierDismissible: false, barrierColor: Color(0x33000000))`
/// (Dart `showCupertinoDialog<bool>`): the affirmative choice pops the modal
/// with `true`, the other with `false`.
struct IosConfirmDialog: View {
    let title: String
    let message: String

    /// The affirmative choice, drawn in the brand colour and shown first.
    let confirmLabel: String
    let cancelLabel: String

    @Environment(\.dismissModal) private var dismissModal

    init(title: String, message: String, confirmLabel: String, cancelLabel: String) {
        self.title = title
        self.message = message
        self.confirmLabel = confirmLabel
        self.cancelLabel = cancelLabel
    }

    /// iOS separator hairline.
    private static let hairline = Color(0x33000000)

    private func action(label: String, affirmative: Bool) -> some View {
        Button {
            dismissModal(affirmative)
        } label: {
            Text(label)
                .textStyle(AppTypography.body(
                    16,
                    weight: affirmative ? .w700 : .w400,
                    color: affirmative ? AppColors.primary : AppColors.textSecondary
                ))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(CupertinoPressStyle())
        .frame(height: 44)
    }

    var body: some View {
        // Material ancestor in Dart only supplies a default text style; every
        // Text here is styled explicitly.
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Text(title)
                    .textStyle(AppTypography.heading(16, height: 1.3))
                    .multilineTextAlignment(.center)
                VGap(6)
                Text(message)
                    .textStyle(AppTypography.body(12.5, color: AppColors.textSecondary, height: 1.35))
                    .multilineTextAlignment(.center)
            }
            .padding(16, 19, 16, 16)
            MaterialDivider(height: 1, thickness: 0.5, color: Self.hairline)
            HStack(spacing: 0) {
                action(label: confirmLabel, affirmative: true)
                    .frame(maxWidth: .infinity)
                // VerticalDivider(width: 1, thickness: 0.5)
                Rectangle()
                    .fill(Self.hairline)
                    .frame(width: 0.5)
                    .frame(width: 1)
                action(label: cancelLabel, affirmative: false)
                    .frame(maxWidth: .infinity)
            }
            .frame(height: 44)
        }
        .frame(width: 270)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

/// `CupertinoButton`'s press feedback: the label fades to 40% while held.
private struct CupertinoPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.4 : 1)
            .animation(.easeOut(duration: configuration.isPressed ? 0.12 : 0.18), value: configuration.isPressed)
    }
}
