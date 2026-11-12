// Port of lib/features/notification/di/notification_module.dart

import Foundation

extension AppContainer {
    /// `pushNotificationServiceProvider` (a `ChangeNotifierProvider`).
    var pushNotificationService: PushNotificationService {
        provide {
            PushNotificationService(
                onMessageReceived: { [weak self] in self?.notificationRemoteList.invalidate() }
            )
        }
    }

    /// `notificationRemoteServiceProvider` — `NotificationRemoteService(FirebaseFunctions.instance)`.
    var notificationRemoteService: NotificationRemoteService {
        provide { NotificationRemoteService(functions) }
    }

    /// `notificationRepositoryProvider`.
    var notificationRepository: NotificationRepository {
        provide { NotificationRepositoryImpl(notificationRemoteService) as NotificationRepository }
    }

    // ---- Use cases ------------------------------------------------------------

    /// `getNotificationsUseCaseProvider`.
    var getNotificationsUseCase: GetNotificationsUseCase {
        provide { GetNotificationsUseCase(notificationRepository) }
    }

    /// `markNotificationReadUseCaseProvider`.
    var markNotificationReadUseCase: MarkNotificationReadUseCase {
        provide { MarkNotificationReadUseCase(notificationRepository) }
    }
}
