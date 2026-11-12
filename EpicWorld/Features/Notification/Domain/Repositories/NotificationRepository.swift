// Port of lib/features/notification/domain/repositories/notification_repository.dart

import Foundation

/// Server-backed notification feed and read markers.
protocol NotificationRepository: AnyObject {
    func getNotifications(accessToken: String, userId: String, role: String) async -> AppResult<[AppNotification]>

    func markNotificationRead(accessToken: String, notificationId: String) async -> AppResult<Bool>
}
