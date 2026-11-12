// Port of lib/features/notification/domain/usecases/get_notifications_use_case.dart

import Foundation

/// The signed-in user's notifications, with read state applied.
final class GetNotificationsUseCase: UseCase {
    private let repository: NotificationRepository

    init(_ repository: NotificationRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: GetNotificationsParams) async -> AppResult<[AppNotification]> {
        await repository.getNotifications(
            accessToken: params.accessToken,
            userId: params.userId,
            role: params.role
        )
    }
}

typealias GetNotificationsParams = (
    accessToken: String,
    userId: String,
    role: String
)
