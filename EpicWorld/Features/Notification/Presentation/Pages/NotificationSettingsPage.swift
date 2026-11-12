// Port of lib/features/notification/presentation/pages/notification_settings_page.dart

import SwiftUI

/// NOTIFICATION SETTINGS — the preference toggles reached from the profile
/// tab's "Notifications" row (distinct from the in-app notification feed opened
/// by the home bell). Push permission uses the device settings, while the
/// account security toggle persists through `dcExec:SetMyTwoFactor`.
struct NotificationSettingsPage: View {
    @Environment(AppContainer.self) private var container

    @State private var twoFactorEnabled: Bool?
    @State private var savingTwoFactor = false

    /// Why the last write failed, shown in place of the row's subtitle.
    @State private var saveError: String?

    /// The in-flight save; cancelled when the page goes away (Dart's
    /// `mounted` checks).
    @State private var saveTask: Task<Void, Never>?

    init() {}

    var body: some View {
        let accountState = container.memberAccount.state
        let account: MemberAccount? = accountState.valueOrNull ?? nil
        let isSignedIn = container.authNotifier.state.isAuthenticated
        let twoFactorEnabled = self.twoFactorEnabled ?? account?.twoFactorEnabled ?? false

        Scaffold(backgroundColor: AppColors.surface, appBar: {
            AppBar(
                title: LocaleKeys.notification_notifications.tr(),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                centerTitle: true
            )
        }) {
            ScrollView {
                VStack(spacing: 0) {
                    PushNotificationSettingsTile()
                    VStack(spacing: 0) {
                        // Section header.
                        HStack(spacing: 0) {
                            Icon(Icons.settings_outlined, size: 20, color: AppColors.primary)
                                .frame(width: 38, height: 38)
                                .boxDecoration(color: AppColors.primarySurface, radius: 12)
                            HGap(12)
                            Text(LocaleKeys.notification_preferences.tr())
                                .textStyle(AppTypography.heading(17))
                            Spacer(minLength: 0)
                        }
                        .padding(16, 12, 16, 12)
                        MaterialDivider(height: 1, thickness: 1, color: AppColors.divider, indent: 16, endIndent: 16)
                        // Email notifications and promotional offers stay hidden
                        // until their own backend preference operations are published.
                        toggle(
                            value: twoFactorEnabled,
                            // Only a session is needed to write this. Waiting for GetMe
                            // to succeed used to leave the switch dead whenever the
                            // account read failed.
                            enabled: isSignedIn && !savingTwoFactor,
                            icon: Icons.lock_outline,
                            color: AppColors.warning,
                            title: LocaleKeys.notification_two_factor_authentication.tr(),
                            subtitle: subtitle(isSignedIn: isSignedIn, accountState: accountState),
                            onChanged: { enabled in
                                saveTask = Task { await setTwoFactor(enabled) }
                            }
                        )
                    }
                    .padding(.vertical, 8)
                    .boxDecoration(
                        color: AppColors.surface,
                        radius: 20,
                        shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 18, offset: Offset(0, 6))]
                    )
                }
                .padding(AppSpacing.screenH)
            }
        }
        .onDisappear { saveTask?.cancel() }
    }

    private func subtitle(isSignedIn: Bool, accountState: AsyncValue<MemberAccount?>) -> String {
        if !isSignedIn { return "Sign in to manage account security" }
        if let error = accountState.error {
            return "Current setting unavailable: \(ApiException.messageFrom(error))"
        }
        if accountState.isLoading { return "Loading account security settings…" }
        return saveError ?? "Extra account security"
    }

    private func toggle(
        value: Bool,
        enabled: Bool,
        icon: IconData,
        color: Color,
        title: String,
        subtitle: String,
        onChanged: @escaping (Bool) -> Void
    ) -> some View {
        HStack(spacing: 0) {
            Icon(icon, size: 20, color: color)
                .frame(width: 40, height: 40)
                .boxDecoration(color: color.withValues(alpha: 0.12), radius: 12)
            HGap(12)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .textStyle(AppTypography.body(15, weight: .w600))
                VGap(2)
                Text(subtitle)
                    .textStyle(AppTypography.body(12.5, color: AppColors.textSecondary))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Switch.adaptive → the Cupertino switch on iOS.
            Toggle("", isOn: Binding(get: { value }, set: { onChanged($0) }))
                .labelsHidden()
                .tint(AppColors.primary)
                .disabled(!enabled)
        }
        .padding(horizontal: 16, vertical: 12)
    }

    private func setTwoFactor(_ enabled: Bool) async {
        guard let user = container.authNotifier.state.user, !savingTwoFactor else { return }
        let previous = self.twoFactorEnabled
            ?? (container.memberAccount.state.valueOrNull ?? nil)?.twoFactorEnabled
            ?? false
        twoFactorEnabled = enabled
        savingTwoFactor = true
        saveError = nil
        do {
            let service = container.notificationRemoteService
            try await container.authNotifier.withValidAccessToken { token in
                try await service.setMyTwoFactor(
                    accessToken: token,
                    userId: user.id,
                    twoFactorEnabled: enabled
                )
            }
            if Task.isCancelled { return }
            // Read the account back and drop the optimistic value, so the switch
            // ends up showing what the backend actually stored rather than what was
            // asked for. A write the server ignores now flips the switch back
            // instead of looking saved until the next launch.
            container.memberAccount.invalidate()
            var reloaded = true
            do {
                _ = try await container.memberAccount.future
            } catch {
                // The write succeeded; only the read-back failed, so keep showing
                // what was asked for rather than reverting the switch.
                reloaded = false
            }
            if Task.isCancelled { return }
            if reloaded { twoFactorEnabled = nil }
            savingTwoFactor = false
        } catch {
            superPrint("SetMyTwoFactor failed: \(error)")
            if Task.isCancelled { return }
            let message = ApiException.messageFrom(error)
            twoFactorEnabled = previous
            savingTwoFactor = false
            saveError = message
            SnackBarCenter.shared.show(message, backgroundColor: AppColors.error, floating: true)
        }
    }
}
