// Port of lib/features/notification/data/datasources/notification_mock_service.dart

import SwiftUI

/// In-memory stand-in for the notifications feed.
final class NotificationMockService {
    init() {}

    /// Instance entry point used by `NotificationRepositoryImpl`.
    func getNotifications() -> [AppNotification] { Self.items }

    /// Mock notifications for the Latest / Unread tabs. Swap for a real feed later.
    static let items: [AppNotification] = [
        AppNotification(
            id: "n1",
            title: "Booking confirmed ✈️",
            body: "Your Yangon → Bangkok flight (EW-7F3K9Q) is confirmed.",
            time: "12m ago",
            icon: Icons.flight_takeoff_rounded,
            color: AppColors.primary,
            read: false
        ),
        AppNotification(
            id: "n2",
            title: "You earned 250 points 🎉",
            body: "Points added from your latest booking. Keep climbing your tier!",
            time: "2h ago",
            icon: Icons.stars_rounded,
            color: AppColors.accent,
            read: false
        ),
        AppNotification(
            id: "n3",
            title: "Member-only fare unlocked",
            body: "Save up to 30% on flights to Singapore this week.",
            time: "5h ago",
            icon: Icons.local_offer_rounded,
            color: AppColors.violet,
            read: false
        ),
        AppNotification(
            id: "n4",
            title: "Visa application update",
            body: "Your Thailand tourist visa is now being processed.",
            time: "Yesterday",
            icon: Icons.badge_rounded,
            color: AppColors.teal,
            read: true
        ),
        AppNotification(
            id: "n5",
            title: "Trip reminder",
            body: "Check-in opens in 24 hours for your upcoming trip.",
            time: "2 days ago",
            icon: Icons.event_available_rounded,
            color: AppColors.info,
            read: true
        ),
        AppNotification(
            id: "n6",
            title: "Welcome to Epic World 👋",
            body: "Thanks for joining. Explore member benefits and start saving.",
            time: "3 days ago",
            icon: Icons.celebration_rounded,
            color: AppColors.rose,
            read: true
        ),
    ]
}
