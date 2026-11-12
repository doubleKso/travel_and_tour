import XCTest
@testable import EpicWorld

/// Ports test/features/notification/data/datasources/push_device_support_test.dart.
///
/// Only the iOS half applies: iOS skips the Google Play services channel and
/// always reports push support as available.
final class PushDeviceSupportTests: XCTestCase {
    func testIOSSkipsTheGooglePlayServicesChannel() async throws {
        let available = try await PushDeviceSupport.hasGooglePlayServices()
        XCTAssertTrue(available)
    }
}
