import XCTest
import SwiftUI
@testable import EpicWorld

/// Ports test/features/notification/domain/entities/notification_response_test.dart.
@MainActor
final class NotificationResponseTests: XCTestCase {
    func testMapsGetMyNotificationsResponseItemsForTheNotificationUI() throws {
        let item = AppNotification.fromApiJson([
            "id": "notification-1",
            "type": "booking",
            "title": "Flight confirmed",
            "body": "Your RGN to MDL flight is confirmed.",
            "sentAt": "2026-08-19T07:58:41.565Z",
            "createdAt": "2026-08-19T07:58:41.565Z",
        ])

        XCTAssertEqual(Endpoints.dcExec, "/dcExec")
        XCTAssertEqual(item.id, "notification-1")
        XCTAssertEqual(item.type, "booking")
        XCTAssertEqual(item.title, "Flight confirmed")
        XCTAssertEqual(item.sentAt, try DateTime.parse("2026-08-19T07:58:41.565Z"))
        XCTAssertEqual(item.icon, Icons.flight_takeoff_rounded)
        XCTAssertEqual(item.color, AppColors.primary)
        XCTAssertTrue(item.copyWith(read: true).read)
    }

    private func notification(type: String, title: String) -> AppNotification {
        AppNotification.fromApiJson([
            "id": "n",
            "type": type,
            "title": title,
            "body": "",
        ])
    }

    func testStylesEachNotificationCategoryLikeTheFeedDesign() {
        let cases: [(String, IconData, Color)] = [
            ("visa", Icons.badge_rounded, AppColors.teal),
            ("points", Icons.stars_rounded, AppColors.accent),
            ("promo", Icons.local_offer_rounded, AppColors.violet),
            ("payment", Icons.payments_rounded, AppColors.success),
            ("reminder", Icons.event_available_rounded, AppColors.info),
            ("welcome", Icons.celebration_rounded, AppColors.rose),
            ("alert", Icons.warning_amber_rounded, AppColors.error),
            ("general", Icons.notifications_rounded, AppColors.primary),
        ]
        for (type, icon, color) in cases {
            let item = notification(type: type, title: "Update")
            XCTAssertEqual(item.icon, icon, type)
            XCTAssertEqual(item.color, color, type)
        }
    }

    func testFallsBackToAWholeWordInTheTitleForAnUnknownType() {
        XCTAssertEqual(
            notification(type: "general", title: "You earned 250 points 🎉").icon,
            Icons.stars_rounded
        )
        XCTAssertEqual(
            notification(type: "general", title: "Member-only fare unlocked").icon,
            Icons.local_offer_rounded
        )
        XCTAssertEqual(
            notification(type: "general", title: "Visa booking confirmed").icon,
            Icons.badge_rounded
        )
        // "point" inside "Appointment" is not a whole-word match.
        XCTAssertEqual(
            notification(type: "general", title: "Appointment scheduled").icon,
            Icons.notifications_rounded
        )
        // A known type wins over the title.
        XCTAssertEqual(
            notification(type: "booking", title: "Visa-free trip confirmed").icon,
            Icons.flight_takeoff_rounded
        )
    }
}
