import XCTest
@testable import EpicWorld

/// Ports the logic asserted by
/// test/features/notification/presentation/widgets/push_notification_settings_tile_test.dart
/// (a widget test) as unit tests of the label rules the tile's `build` uses.
@MainActor
final class PushNotificationSettingsTileTests: XCTestCase {
    func testMissingPlayServicesExplainsAvailabilityAndCanBeRechecked() {
        // The fake service: permission granted, Play services unavailable.
        XCTAssertEqual(
            PushNotificationSettingsTile.statusKey(
                googlePlayServicesUnavailable: true,
                hasError: false,
                hasPermission: true,
                permissionDenied: false
            ),
            LocaleKeys.notification_push_google_services_unavailable
        )
        XCTAssertEqual(
            PushNotificationSettingsTile.actionKey(
                googlePlayServicesUnavailable: true,
                hasError: false,
                openSettings: true
            ),
            LocaleKeys.notification_push_check_again
        )

        // "Check again" re-ran the check and Play services became available.
        XCTAssertEqual(
            PushNotificationSettingsTile.statusKey(
                googlePlayServicesUnavailable: false,
                hasError: false,
                hasPermission: true,
                permissionDenied: false
            ),
            LocaleKeys.notification_push_enabled
        )
    }

    func testStatusAndActionFollowTheTilePrecedence() {
        XCTAssertEqual(
            PushNotificationSettingsTile.statusKey(
                googlePlayServicesUnavailable: false,
                hasError: true,
                hasPermission: true,
                permissionDenied: false
            ),
            LocaleKeys.notification_push_error
        )
        XCTAssertEqual(
            PushNotificationSettingsTile.statusKey(
                googlePlayServicesUnavailable: false,
                hasError: false,
                hasPermission: false,
                permissionDenied: true
            ),
            LocaleKeys.notification_push_disabled
        )
        XCTAssertEqual(
            PushNotificationSettingsTile.statusKey(
                googlePlayServicesUnavailable: false,
                hasError: false,
                hasPermission: false,
                permissionDenied: false
            ),
            LocaleKeys.notification_push_not_requested
        )
        XCTAssertEqual(
            PushNotificationSettingsTile.actionKey(googlePlayServicesUnavailable: false, hasError: true, openSettings: true),
            LocaleKeys.notification_push_retry
        )
        XCTAssertEqual(
            PushNotificationSettingsTile.actionKey(googlePlayServicesUnavailable: false, hasError: false, openSettings: true),
            LocaleKeys.notification_push_open_settings
        )
        XCTAssertEqual(
            PushNotificationSettingsTile.actionKey(googlePlayServicesUnavailable: false, hasError: false, openSettings: false),
            LocaleKeys.notification_push_enable
        )
    }
}
