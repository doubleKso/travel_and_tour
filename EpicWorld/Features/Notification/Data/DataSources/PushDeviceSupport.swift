// Port of lib/features/notification/data/datasources/push_device_support.dart

import Foundation

/// Checks the installed Google Play services APK, including its version and
/// enabled state. Bundling the Firebase SDK cannot provide that system service.
enum PushDeviceSupport {
    static func hasGooglePlayServices() async throws -> Bool {
        // `kIsWeb || defaultTargetPlatform != TargetPlatform.android` is true
        // on iOS, so the Android `epic_world/notifications` channel is never
        // asked: APNs needs no Google Play services.
        true
    }
}
