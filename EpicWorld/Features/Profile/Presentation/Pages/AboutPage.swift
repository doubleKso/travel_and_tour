// Port of lib/features/profile/presentation/pages/about_page.dart
import SwiftUI

/// ABOUT EPIC WORLD — a compact intro hero plus contact details.
struct AboutPage: View {
    init() {}

    fileprivate static let site = "https://website-epic-world.vercel.app"

    // `dial` marks the rows that should hand their number to the dialler; the
    // address, email and opening hours are read-only.
    private static let contacts: [(icon: IconData, text: String, dial: Bool)] = [
        (
            icon: Icons.location_on_outlined,
            text: "No. 199, Ground Floor, Pansoedan Street, Middle Block, Yangon 11182",
            dial: false
        ),
        (icon: Icons.phone_outlined, text: AppConsts.officeMobile, dial: true),
        (icon: Icons.phone_outlined, text: AppConsts.officeLandline, dial: true),
        (icon: Icons.email_outlined, text: "info@epicworldtravel.com", dial: false),
        (
            icon: Icons.access_time_outlined,
            text: "Mon – Sat, 9:00 AM – 6:00 PM",
            dial: false
        ),
    ]

    /// One social / contact channel row.
    typealias Social = (
        label: String,
        color: Color,
        handle: String,
        svg: String?,
        icon: IconData?,
        action: ((String) async -> Void)?
    )

    /// Social / contact channels, rendered as the app's brand SVGs (tinted white
    /// on their coloured badge).
    ///
    /// Built per call rather than held in a `static let`: a static is
    /// initialised once, on first access, which froze these labels in whichever
    /// language happened to be active the first time the page was opened.
    static func socials() -> [Social] {
        [
            (
                label: LocaleKeys.common_phone.tr(),
                color: Color(0xFF25A244),
                handle: AppConsts.officeMobile,
                svg: AppAssets.channelCall,
                icon: nil,
                action: { await ContactLauncher.dial($0) }
            ),
            (
                label: LocaleKeys.profile_viber.tr(),
                color: Color(0xFF7360F2),
                handle: AppConsts.officeMobile,
                svg: AppAssets.channelViber,
                icon: nil,
                action: { await ContactLauncher.viber($0) }
            ),
            (
                label: LocaleKeys.profile_messenger.tr(),
                color: Color(0xFF0084FF),
                handle: AppConsts.messengerPage,
                svg: AppAssets.channelMessenger,
                icon: nil,
                action: { await ContactLauncher.messenger($0) }
            ),
        ]
    }

    var body: some View {
        // Rebuilt on every render so the labels follow the current language.
        let socials = AboutPage.socials()

        Scaffold(
            backgroundColor: AppColors.surface,
            appBar: {
                AppBar(
                    title: LocaleKeys.profile_about_epic_world.tr(),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    centerTitle: true
                )
            }
        ) {
            ScrollView {
                VStack(spacing: 0) {
                    Hero()

                    // ---- Get in touch ----
                    VStack(alignment: .leading, spacing: 0) {
                        sectionTitle(LocaleKeys.profile_get_in_touch.tr())
                        VGap(16)
                        VStack(spacing: 0) {
                            ForEach(Array(AboutPage.contacts.enumerated()), id: \.offset) { i, contact in
                                ContactRow(
                                    icon: contact.icon,
                                    text: contact.text,
                                    onTap: AboutPage.dialAction(contact.dial, contact.text)
                                )
                                if i < AboutPage.contacts.count - 1 {
                                    MaterialDivider(
                                        height: 1,
                                        thickness: 1,
                                        color: AppColors.dividerLight,
                                        indent: 62,
                                        endIndent: 14
                                    )
                                }
                            }
                        }
                        .padding(6)
                        .boxDecoration(
                            color: AppColors.surface,
                            radius: 18,
                            shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: Offset(0, 6))]
                        )

                        // ---- Follow us (social media) ----
                        VGap(28)
                        sectionTitle(LocaleKeys.profile_follow_us.tr())
                        VGap(16)
                        ForEach(Array(socials.enumerated()), id: \.offset) { i, social in
                            if i > 0 { VGap(12) }
                            SocialRow(
                                label: social.label,
                                color: social.color,
                                svg: social.svg,
                                icon: social.icon,
                                handle: social.handle,
                                action: social.action
                            )
                        }

                        VGap(20)
                        Text(LocaleKeys.profile_2026_epic_world_travel_tours.tr())
                            .textStyle(AppTypography.body(12, color: AppColors.textPrimary))
                            .frame(maxWidth: .infinity)
                    }
                    .padding(20, 26, 20, 32)
                }
            }
        }
    }

    /// `_contacts[i].dial ? () => ContactLauncher.dial(context, text) : null`.
    private static func dialAction(_ dial: Bool, _ number: String) -> (() -> Void)? {
        guard dial else { return nil }
        return { Task { await ContactLauncher.dial(number) } }
    }

    private func sectionTitle(_ title: String) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(AppColors.primary)
                .frame(width: 4, height: 20)
            HGap(10)
            Text(title)
                .textStyle(AppTypography.heading(20))
        }
    }
}

/// Modern, primary-light hero: rounded-bottom green sheet with a soft glow,
/// a white "About Us" badge, the intro copy and the brand collage image.
private struct Hero: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(LocaleKeys.profile_epic_world_travel_tours.tr())
                .textStyle(AppTypography.heading(26, color: Colors.white, height: 1.15))
            VGap(10)
            Text(LocaleKeys.profile_for_over_decade_epic_world_has.tr())
                .textStyle(AppTypography.body(13.5, color: Colors.white.withValues(alpha: 0.92), height: 1.55))
            VGap(20)
            // Brand collage image, floated on a white frame with a shadow.
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 170)
                .overlay {
                    NetworkImage("\(AboutPage.site)/images/about.png", height: 170, fit: .cover) {
                        AppColors.primarySurface
                    } error: {
                        ZStack {
                            AppColors.primarySurface
                            Icon(Icons.image_outlined, color: AppColors.textTertiary)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(5)
                .boxDecoration(
                    color: Colors.white,
                    radius: 20,
                    shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 18, offset: Offset(0, 10))]
                )
        }
        .padding(24, 26, 24, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Soft decorative glow, top-right (Positioned(top: -60, right: -50)).
        .background(alignment: .topTrailing) {
            Circle()
                .fill(RadialGradient(
                    colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0.0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: 90
                ))
                .frame(width: 180, height: 180)
                .offset(x: 50, y: -60)
        }
        .background(AppColors.primaryLight)
        .clipShape(UnevenRoundedRectangle(cornerRadii: BorderRadius.vertical(bottom: 30)))
    }
}

private struct ContactRow: View {
    let icon: IconData
    let text: String

    /// Nil for the rows that are pure information (address, email, hours);
    /// the phone rows pass the tap through to the dialler.
    let onTap: (() -> Void)?

    var body: some View {
        if let onTap {
            Button(action: onTap) {
                row.contentShape(Rectangle())
            }
            .buttonStyle(InkButtonStyle(cornerRadius: 12))
        } else {
            row
        }
    }

    private var row: some View {
        HStack(alignment: .center, spacing: 0) {
            Icon(icon, size: 19, color: AppColors.primary)
                .frame(width: 40, height: 40)
                .boxDecoration(color: AppColors.primarySurface, radius: 12)
            HGap(14)
            Text(text)
                .textStyle(AppTypography.body(14, weight: .w500, height: 1.4))
                .frame(maxWidth: .infinity, alignment: .leading)
            // A dialable row earns a chevron so it reads as tappable.
            if onTap != nil {
                Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textTertiary)
            }
        }
        .padding(8)
    }
}

/// One social channel rendered as a full-width card row: a brand-coloured icon
/// badge on the left with the channel name and handle beside it. Each row hands
/// its support address to the relevant installed app, or its web/store fallback.
private struct SocialRow: View {
    let label: String
    let color: Color
    let svg: String?
    let icon: IconData?
    let handle: String
    let action: ((String) async -> Void)?

    private func open() {
        if let action {
            Task { await action(handle) }
            return
        }
        SnackBarCenter.shared.show("\(label): \(handle)", floating: true)
    }

    var body: some View {
        Button(action: open) {
            HStack(spacing: 0) {
                // Brand-coloured icon badge with a gradient + soft lift.
                Group {
                    if let svg {
                        AppImage(svg, width: 22, height: 22, tint: Colors.white)
                    } else if let icon {
                        Icon(icon, size: 24, color: Colors.white)
                    }
                }
                .frame(width: 46, height: 46)
                .boxDecoration(
                    gradient: LinearGradient(
                        colors: [Color.lerp(color, Colors.white, 0.25), color],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    radius: 14,
                    shadows: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10, offset: Offset(0, 5))]
                )
                HGap(14)
                VStack(alignment: .leading, spacing: 0) {
                    Text(label)
                        .textStyle(AppTypography.body(16, weight: .w600, color: AppColors.textPrimary))
                    VGap(2)
                    Text(handle)
                        .textStyle(AppTypography.body(12.5, color: AppColors.textPrimary))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textTertiary)
            }
            // padding 12 inside the 1pt border.
            .padding(13)
            .contentShape(Rectangle())
        }
        .buttonStyle(InkButtonStyle(cornerRadius: 16))
        .boxDecoration(
            color: Colors.white,
            radius: 16,
            borderColor: AppColors.dividerLight,
            shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: Offset(0, 5))]
        )
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }
}
