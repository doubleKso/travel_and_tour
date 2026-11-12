// Port of lib/features/notification/data/repositories/notification_repository_impl.dart

import Foundation

final class NotificationRepositoryImpl: NotificationRepository {
    private let remote: NotificationRemoteService

    init(_ remote: NotificationRemoteService) {
        self.remote = remote
    }

    func getNotifications(accessToken: String, userId: String, role: String) async -> AppResult<[AppNotification]> {
        do {
            // `Future.wait([...])`: both calls run at once.
            async let notificationsRequest = remote.getMyNotifications(
                accessToken: accessToken,
                userId: userId,
                role: role
            )
            async let readIdsRequest = remote.getMyNotificationReads(accessToken: accessToken)
            let notifications = try await notificationsRequest
            let readIds = try await readIdsRequest
            return .success(
                notifications.map { notification in
                    notification.copyWith(read: readIds.contains(notification.id))
                }
            )
        } catch {
            return .failure(FailureMapper.from(error))
        }
    }

    func markNotificationRead(accessToken: String, notificationId: String) async -> AppResult<Bool> {
        do {
            try await remote.insertNotificationRead(accessToken: accessToken, notificationId: notificationId)
            return .success(true)
        } catch {
            return .failure(FailureMapper.from(error))
        }
    }
}
