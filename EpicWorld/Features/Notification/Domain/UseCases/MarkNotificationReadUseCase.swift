// Port of lib/features/notification/domain/usecases/mark_notification_read_use_case.dart

import Foundation

/// Records that the user opened a notification.
final class MarkNotificationReadUseCase: UseCase {
    private let repository: NotificationRepository

    init(_ repository: NotificationRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: MarkNotificationReadParams) async -> AppResult<Bool> {
        await repository.markNotificationRead(
            accessToken: params.accessToken,
            notificationId: params.notificationId
        )
    }
}

typealias MarkNotificationReadParams = (
    accessToken: String,
    notificationId: String
)
