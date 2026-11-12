// Port of lib/features/profile/presentation/pages/profile_page.dart
import SwiftUI
import UIKit

/// Recovers pubspec's build number from an Android split-APK `versionCode`.
///
/// `flutter build apk --split-per-abi` rewrites each APK's version code as
/// `abiCode * 1000 + buildNumber`; that only ever happens on Android, so on
/// iOS the bundle's build number is returned untouched (the Android branch is
/// dropped as it cannot run here).
private func buildNumberFor(_ buildNumber: String) -> String {
    buildNumber
}

private extension AppContainer {
    /// `_appVersionProvider` — `version: 1.0.0 (10)` from the bundle
    /// (`package_info_plus` on iOS reads the same two Info.plist keys).
    var appVersion: AsyncResource<String> {
        provide("profile.appVersion") {
            AsyncResource {
                let info = Bundle.main.infoDictionary
                let version = info?["CFBundleShortVersionString"] as? String ?? ""
                let build = buildNumberFor(info?["CFBundleVersion"] as? String ?? "")
                let buildSuffix = build.isEmpty ? "" : " (\(build))"
                return "version: \(version)\(buildSuffix)"
            }
        }
    }
}

/// PROFILE — user info, account actions, preferences and support.
struct ProfilePage: View {
    let onBack: (() -> Void)?

    init(onBack: (() -> Void)? = nil) {
        self.onBack = onBack
    }

    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router

    private func open(_ route: Route) {
        router.push(route)
    }

    private func confirmLogout() async {
        let confirmed = await showLogoutConfirmationDialog()
        if !confirmed { return }
        await container.authNotifier.logout()
    }

    private func refreshProfile() async {
        container.myPoints.invalidate()
        container.appVersion.invalidate()
        // Future.wait([...]) — each one's failure is swallowed (`catchError`).
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                _ = await container.authNotifier.refreshCurrentUser()
            }
            group.addTask { @MainActor in
                _ = try? await container.myPoints.future
            }
            group.addTask { @MainActor in
                _ = try? await container.appVersion.future
            }
        }
    }

    /// Solid green heading the identity card overlaps — mirrors the Ticket
    /// Details header (back button + centred title, no decorative shape).
    private func header(topPad: CGFloat) -> some View {
        HStack(spacing: 0) {
            Button {
                if let onBack {
                    onBack()
                } else {
                    Task { await router.maybePop() }
                }
            } label: {
                Icon(Icons.arrow_back, color: Colors.white)
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Text(LocaleKeys.profile_profile.tr())
                .textStyle(AppTypography.heading(20, color: Colors.white))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            HGap(48)
        }
        .padding(4, topPad + 6, 4, 56)
        .frame(maxWidth: .infinity)
        .background(AppColors.primary)
    }

    var body: some View {
        let auth = container.authNotifier.state
        let points = container.currentMemberPoints
        let appVersion = container.appVersion.state

        GeometryReader { proxy in
            let topPad = proxy.safeAreaInsets.top
            ScrollView {
                VStack(spacing: 0) {
                    // Green heading with the identity card overlapping its lower edge —
                    // same overlay pattern as the Ticket Details header.
                    header(topPad: topPad)
                        .overlay(alignment: .bottom) {
                            ProfileHeader(
                                avatar: avatar(auth),
                                name: auth.displayName,
                                email: auth.email ?? "guest@gmail.com",
                                points: points
                            )
                            .padding(.horizontal, AppSpacing.screenH)
                            .offset(y: 72)
                        }
                        .zIndex(1)
                    VGap(96)

                    VStack(spacing: 0) {
                        group(LocaleKeys.profile_account.tr(), [
                            Item(
                                icon: Icons.manage_accounts_outlined,
                                label: LocaleKeys.profile_manage_profile.tr(),
                                onTap: { open(.manageProfile) }
                            ),
                            Item(
                                icon: Icons.lock_outline,
                                label: LocaleKeys.profile_change_password.tr(),
                                onTap: { open(.changePassword) }
                            ),
                        ])
                        VGap(16)
                        group(LocaleKeys.profile_preferences.tr(), [
                            Item(
                                icon: Icons.language,
                                label: LocaleKeys.profile_language.tr(),
                                onTap: { open(.language) }
                            ),
                            Item(
                                icon: Icons.notifications_none,
                                label: LocaleKeys.notification_notifications.tr(),
                                onTap: { open(.notificationSettings) }
                            ),
                        ])
                        VGap(16)
                        group(LocaleKeys.profile_support.tr(), [
                            Item(
                                icon: Icons.help_outline,
                                label: LocaleKeys.profile_help_center.tr(),
                                onTap: { open(.helpCenter) }
                            ),
                            Item(
                                icon: Icons.info_outline,
                                label: LocaleKeys.profile_about_epic_world.tr(),
                                onTap: { open(.about) }
                            ),
                        ])
                        VGap(16)
                        appVersion.when(
                            data: { version in
                                AnyView(
                                    Text(version)
                                        .textStyle(AppTypography.body(16, color: AppColors.textPrimary))
                                        .multilineTextAlignment(.center)
                                )
                            },
                            error: { _ in AnyView(EmptyView()) },
                            loading: { AnyView(VGap(17)) }
                        )
                        VGap(12)
                        Button {
                            Task { await confirmLogout() }
                        } label: {
                            HStack(spacing: 0) {
                                Icon(Icons.logout, size: 18, color: AppColors.error)
                                HGap(8)
                                Text(LocaleKeys.profile_log_out.tr())
                            }
                        }
                        .buttonStyle(OutlinedButtonStyle(
                            foregroundColor: AppColors.error,
                            borderColor: AppColors.error
                        ))
                    }
                    .padding(.horizontal, AppSpacing.screenH)
                }
            }
            .refreshable { await refreshProfile() }
            .ignoresSafeArea(edges: .top)
        }
        .background(AppColors.surface.ignoresSafeArea())
    }

    /// A user-picked avatar wins; otherwise the account's photo, then the
    /// bundled placeholder (`CircleAvatar(backgroundColor: white, backgroundImage: …)`).
    @ViewBuilder
    private func avatar(_ auth: AuthState) -> some View {
        if let bytes = auth.avatarBytes {
            if let image = UIImage(data: bytes) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Colors.white
            }
        } else if let url = auth.user?.avatarUrl, !url.isEmpty {
            NetworkImage(url, fit: .cover) {
                Colors.white
            } error: {
                Colors.white
            }
        } else {
            AppImage(AppAssets.profilePlaceholder, fit: .cover)
        }
    }

    private func group(_ title: String, _ items: [Item]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .textStyle(AppTypography.body(13, weight: .w700, color: AppColors.textSecondary))
                .padding(.leading, 4)
                .padding(.bottom, 8)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    Button(action: item.onTap) {
                        // ListTile: 16pt start / 24pt end padding, 56pt tall,
                        // 16pt between the leading icon and the title.
                        HStack(spacing: 0) {
                            Icon(item.icon, color: AppColors.primary)
                            HGap(16)
                            Text(item.label)
                                .textStyle(AppTypography.body(15, weight: .w500))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            HGap(16)
                            Icon(Icons.chevron_right, color: AppColors.textTertiary)
                        }
                        .padding(16, 0, 24, 0)
                        .frame(minHeight: 56)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.ink)
                    if i < items.count - 1 {
                        MaterialDivider(
                            height: 1,
                            thickness: 1,
                            color: Color(0xFFE0E0E0),
                            indent: 16,
                            endIndent: 16
                        )
                    }
                }
            }
            .boxDecoration(
                color: AppColors.surface,
                radius: 16,
                shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 18, offset: Offset(0, 6))]
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct Item {
    let icon: IconData
    let label: String
    let onTap: () -> Void
}

/// Profile header — a tall green heading banner with a white identity card
/// (ringed avatar, name, email and a role/points badge) overlapping it.
private struct ProfileHeader<Avatar: View>: View {
    let avatar: Avatar
    let name: String
    let email: String
    let points: Int

    var body: some View {
        // White identity card that overlaps the green heading behind it.
        HStack(spacing: 0) {
            // Avatar with a soft brand-green ring.
            avatar
                .frame(width: 64, height: 64)
                .background(Colors.white)
                .clipShape(Circle())
                // padding 3 plus the 2pt border a Flutter Container adds.
                .padding(5)
                .boxDecoration(
                    circle: true,
                    borderColor: AppColors.primary.withValues(alpha: 0.25),
                    borderWidth: 2,
                    shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: Offset(0, 4))]
                )
            HGap(16)
            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                    .textStyle(AppTypography.heading(22, color: AppColors.textPrimary))
                    .lineLimit(1)
                    .truncationMode(.tail)
                VGap(4)
                Text(email)
                    .textStyle(AppTypography.body(13, color: AppColors.textSecondary))
                    .lineLimit(1)
                    .truncationMode(.tail)
                VGap(10)
                badge()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .boxDecoration(
            color: AppColors.surface,
            radius: 20,
            shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 24, offset: Offset(0, 10))]
        )
    }

    /// Loyalty pill shown under the name.
    private func badge() -> some View {
        let icon = Icons.stars_rounded
        let label = "\(Formatters.grouped(points)) pts"
        return HStack(spacing: 0) {
            Icon(icon, size: 14, color: AppColors.info)
            HGap(5)
            Text(label)
                .textStyle(AppTypography.body(12, weight: .w600, color: AppColors.info))
        }
        .padding(horizontal: 10, vertical: 5)
        .boxDecoration(color: AppColors.info.withValues(alpha: 0.12), radius: 20)
    }
}
