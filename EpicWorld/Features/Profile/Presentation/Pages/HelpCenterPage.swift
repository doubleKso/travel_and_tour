// Port of lib/features/profile/presentation/pages/help_center_page.dart
import SwiftUI

/// HELP CENTER — simple, responsive contact details for travellers needing
/// support before, during or after a trip.
struct HelpCenterPage: View {
    init() {}

    fileprivate static let email = "info@epicworldtravel.com"

    var body: some View {
        Scaffold(
            backgroundColor: AppColors.background,
            appBar: {
                AppBar(
                    title: LocaleKeys.profile_help_center.tr(),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    centerTitle: true
                )
            }
        ) {
            GeometryReader { proxy in
                ScrollView {
                    // Center → ConstrainedBox(maxWidth: 640,
                    // minHeight: (maxHeight - 40).clamp(0, ∞)) → the card.
                    ContactCard(minHeight: max(0, proxy.size.height - 40))
                        .frame(maxWidth: 640)
                        .frame(maxWidth: .infinity)
                        .padding(20)
                }
            }
        }
    }
}

private struct ContactCard: View {
    let minHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Contact information")
                .textStyle(AppTypography.heading(24, color: Colors.white))
            VGap(6)
            Text("Prefer to reach us directly? Here's how.")
                .textStyle(AppTypography.body(14, color: Colors.white.withValues(alpha: 0.85)))
            VGap(26)
            ContactItem(
                icon: Icons.location_on_outlined,
                title: "Visit us",
                detail: "No. 199, Ground Floor, Pansoedan Street, Middle Block, Yangon 11182"
            )
            VGap(20)
            ContactItem(
                icon: Icons.phone_outlined,
                title: "Call us",
                detail: "\(AppConsts.officeMobile) · \(AppConsts.officeLandline)",
                onTap: { Task { await ContactLauncher.dial(AppConsts.officeMobile) } }
            )
            VGap(20)
            ContactItem(
                icon: Icons.email_outlined,
                title: "Email us",
                detail: HelpCenterPage.email,
                onTap: { Task { await ContactLauncher.email(HelpCenterPage.email) } }
            )
            VGap(20)
            ContactItem(
                icon: Icons.access_time_outlined,
                title: "Office hours",
                detail: "Mon – Sat, 9:00 AM – 6:00 PM"
            )
        }
        .padding(24, 28, 24, 24)
        // The ConstrainedBox's minimum height reaches the card, which grows
        // to fill it with its content at the top.
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .boxDecoration(
            gradient: AppColors.heroGradient,
            radius: 24,
            shadows: [BoxShadow(color: AppColors.primaryDark.withValues(alpha: 0.2), blurRadius: 20, offset: Offset(0, 10))]
        )
    }
}

private struct ContactItem: View {
    let icon: IconData
    let title: String
    let detail: String
    var onTap: (() -> Void)? = nil

    var body: some View {
        if let onTap {
            Button(action: onTap) {
                content
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
            }
            .buttonStyle(InkButtonStyle(cornerRadius: 14))
        } else {
            content
        }
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 0) {
            Icon(icon, size: 24, color: Colors.white)
                .frame(width: 48, height: 48)
                .boxDecoration(color: Colors.white.withValues(alpha: 0.18), radius: 14)
            HGap(14)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .textStyle(AppTypography.heading(16, color: Colors.white))
                VGap(3)
                Text(detail)
                    .textStyle(AppTypography.body(14, color: Colors.white.withValues(alpha: 0.9), height: 1.4))
            }
            .padding(.top, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
