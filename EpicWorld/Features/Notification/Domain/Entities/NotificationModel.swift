// Port of lib/features/notification/domain/entities/notification_model.dart

import SwiftUI

/// A single in-app notification shown in the Notifications screen.
struct AppNotification {
    let id: String
    let type: String
    let title: String
    let body: String
    let sentAt: DateTime?
    let createdAt: DateTime?

    /// Relative time label, e.g. "2h ago" (kept as a string for the mock).
    let time: String
    let icon: IconData
    let color: Color
    let read: Bool

    init(
        id: String,
        type: String = "general",
        title: String,
        body: String,
        time: String,
        icon: IconData,
        color: Color,
        sentAt: DateTime? = nil,
        createdAt: DateTime? = nil,
        read: Bool = false
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.time = time
        self.icon = icon
        self.color = color
        self.sentAt = sentAt
        self.createdAt = createdAt
        self.read = read
    }

    static func fromApiJson(_ json: JSON) -> AppNotification {
        let sentAt = DateTime.tryParse(Dart.str(json["sentAt"]) ?? "")
        let createdAt = DateTime.tryParse(Dart.str(json["createdAt"]) ?? "")
        let type = Dart.str(json["type"]) ?? "general"
        let title = Dart.str(json["title"]) ?? ""
        let (icon, color) = styleFor(type, title)
        return AppNotification(
            id: Dart.str(json["id"]) ?? "",
            type: type,
            title: title,
            body: Dart.str(json["body"]) ?? "",
            time: relativeTime(sentAt ?? createdAt),
            icon: icon,
            color: color,
            sentAt: sentAt,
            createdAt: createdAt
        )
    }

    func copyWith(read: Bool? = nil) -> AppNotification {
        AppNotification(
            id: id,
            type: type,
            title: title,
            body: body,
            time: time,
            icon: icon,
            color: color,
            sentAt: sentAt,
            createdAt: createdAt,
            read: read ?? self.read
        )
    }

    private static func relativeTime(_ date: DateTime?) -> String {
        guard let date else { return "" }
        let elapsed = DateTime.now().toUtc().difference(date.toUtc())
        if elapsed.inMinutes < 1 { return "Just now" }
        if elapsed.inHours < 1 { return "\(elapsed.inMinutes)m ago" }
        if elapsed.inDays < 1 { return "\(elapsed.inHours)h ago" }
        return "\(elapsed.inDays)d ago"
    }

    /// (keywords, icon, tint) per category, most specific first — a
    /// "Visa booking confirmed" title reads as visa, not booking.
    private static let categories: [(keywords: [String], icon: IconData, color: Color)] = [
        (["visa"], Icons.badge_rounded, AppColors.teal),
        (["points", "reward", "rewards", "loyalty", "tier"], Icons.stars_rounded, AppColors.accent),
        (["payment", "refund"], Icons.payments_rounded, AppColors.success),
        (["booking", "flight", "ticket"], Icons.flight_takeoff_rounded, AppColors.primary),
        (["promo", "promotion", "offer", "deal", "discount", "fare"], Icons.local_offer_rounded, AppColors.violet),
        (["reminder", "trip", "check-in"], Icons.event_available_rounded, AppColors.info),
        (["welcome"], Icons.celebration_rounded, AppColors.rose),
        (["warning", "alert"], Icons.warning_amber_rounded, AppColors.error),
    ]

    /// The icon and tint for a notification. The `type` is matched first; a
    /// type the app doesn't know (the default is "general") falls back to a
    /// whole-word keyword in the `title`, so "You earned 250 points" still
    /// gets the points star.
    private static func styleFor(_ type: String, _ title: String) -> (IconData, Color) {
        let kind = type.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        for category in categories where category.keywords.contains(kind) {
            return (category.icon, category.color)
        }
        let heading = title.lowercased()
        for category in categories {
            let matches = category.keywords.contains { keyword in
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b"
                return heading.range(of: pattern, options: .regularExpression) != nil
            }
            if matches { return (category.icon, category.color) }
        }
        return (Icons.notifications_rounded, AppColors.primary)
    }
}
