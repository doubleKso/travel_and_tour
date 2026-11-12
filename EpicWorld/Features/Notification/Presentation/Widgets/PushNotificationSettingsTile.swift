// Port of lib/features/notification/presentation/widgets/push_notification_settings_tile.dart

import SwiftUI

/// Reports the device's actual permission. A local toggle cannot disable remote
/// alerts that the OS displays while the app is terminated.
struct PushNotificationSettingsTile: View {
    @Environment(AppContainer.self) private var container

    init() {}

    var body: some View {
        let service = container.pushNotificationService
        if service.isSupported {
            content(service)
        }
    }

    private func content(_ service: PushNotificationService) -> some View {
        let unavailable = service.googlePlayServicesUnavailable
        let status = Self.statusKey(
            googlePlayServicesUnavailable: unavailable,
            hasError: service.hasError,
            hasPermission: service.hasPermission,
            permissionDenied: service.permissionDenied
        )
        let openSettings = service.hasPermission || service.permissionDenied
        return VStack(alignment: .leading, spacing: 0) {
            // ListTile(contentPadding: EdgeInsets.zero, leading:, title:, subtitle:).
            HStack(spacing: 0) {
                Icon(Icons.notifications_active_outlined, color: AppColors.primary)
                HGap(16)
                VStack(alignment: .leading, spacing: 0) {
                    Text(LocaleKeys.notification_push_notifications.tr())
                        .textStyle(AppTypography.bodyLarge)
                    Text(status.tr())
                        .textStyle(AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 8)
            .frame(minHeight: 72)
            Button {
                Task {
                    if service.hasError || unavailable {
                        await service.initialize()
                        await service.refreshPermission()
                    } else if openSettings {
                        await service.openSettings()
                    } else {
                        await service.requestPermission()
                    }
                }
            } label: {
                Text(
                    Self.actionKey(
                        googlePlayServicesUnavailable: unavailable,
                        hasError: service.hasError,
                        openSettings: openSettings
                    ).tr()
                )
                .textStyle(AppTypography.labelLarge.copyWith(
                    color: service.isRequestingPermission ? AppTheme.disabledForeground : AppColors.primary
                ))
            }
            .buttonStyle(TextButtonStyle())
            .disabled(service.isRequestingPermission)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Card, themed: white, flat, 16pt corners, hairline border.
        .boxDecoration(color: AppColors.surface, radius: AppTheme.radius, borderColor: AppColors.border)
        .padding(.bottom, 16)
    }

    /// The subtitle key `build` chooses for the device's permission state.
    static func statusKey(
        googlePlayServicesUnavailable unavailable: Bool,
        hasError: Bool,
        hasPermission: Bool,
        permissionDenied: Bool
    ) -> String {
        if unavailable { return LocaleKeys.notification_push_google_services_unavailable }
        if hasError { return LocaleKeys.notification_push_error }
        if hasPermission { return LocaleKeys.notification_push_enabled }
        if permissionDenied { return LocaleKeys.notification_push_disabled }
        return LocaleKeys.notification_push_not_requested
    }

    /// The action button's label key `build` chooses.
    static func actionKey(googlePlayServicesUnavailable unavailable: Bool, hasError: Bool, openSettings: Bool) -> String {
        if unavailable { return LocaleKeys.notification_push_check_again }
        if hasError { return LocaleKeys.notification_push_retry }
        if openSettings { return LocaleKeys.notification_push_open_settings }
        return LocaleKeys.notification_push_enable
    }
}
