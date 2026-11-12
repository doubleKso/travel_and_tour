// Port of lib/features/notification/presentation/providers/notification_providers.dart

import Foundation
import Observation

/// The signed-in user as the notification feed needs it — Dart's record
/// `(id: state.user!.id, role: state.user!.role)`.
private struct NotificationUser: Hashable {
    let id: String
    let role: String
}

/// `ref.watch(authNotifierProvider.select((state) => state.user == null ? null
/// : (id: …, role: …)))`.
///
/// `AsyncResource` reloads whenever anything its `dependencies` closure read
/// changes, so depending on `authNotifier.state` directly would reload the
/// feed on every auth update (loading flags, profile refreshes). This keeps an
/// observable copy of the selected value that only changes when the value
/// itself does — Riverpod's `select`.
@MainActor
@Observable
private final class NotificationUserSelection {
    private(set) var value: NotificationUser?
    private let select: () -> NotificationUser?

    init(_ select: @escaping () -> NotificationUser?) {
        self.select = select
        self.value = select()
        track()
    }

    private func track() {
        let current = withObservationTracking {
            select()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.track() }
        }
        if current != value { value = current }
    }
}

/// Holds `locallyReadNotificationIdsProvider`'s state for one signed-in user;
/// a different user id starts a fresh, empty set (the provider's
/// `ref.watch(authNotifierProvider.select((state) => state.user?.id))`).
private final class LocallyReadNotificationIdsScope {
    var userId: String?
    var box: StateBox<Set<String>>?
}

/// Riverpod's `AsyncValue.whenData`: maps the data and keeps the loading,
/// refreshing and error flags as they are.
@MainActor
private func notificationWhenData<T, R>(_ value: AsyncValue<T>, _ transform: (T) -> R) -> AsyncValue<R> {
    var mapped: AsyncValue<R>
    if let data = value.valueOrNull {
        mapped = .data(transform(data))
        if let error = value.error { mapped = mapped.failed(error) }
    } else if let error = value.error {
        mapped = .error(error)
    } else {
        return .loading
    }
    if value.isRefreshing {
        mapped = mapped.markRefreshing()
    } else if value.isReloading {
        mapped = mapped.markReloading()
    } else if value.isLoading {
        return .loading
    }
    return mapped
}

extension AppContainer {
    /// Created before the feed resource so its own first read of the auth
    /// state is not recorded as one of the resource's dependencies.
    private var notificationUserSelection: NotificationUserSelection {
        provide {
            NotificationUserSelection { [unowned self] in
                guard let user = self.authNotifier.state.user else { return nil }
                return NotificationUser(id: user.id, role: user.role)
            }
        }
    }

    /// Observe this when connecting the backend's device-registration endpoint.
    /// Its value changes when Firebase rotates the token; it can initially be null.
    /// (`fcmTokenProvider`.)
    var fcmToken: String? {
        pushNotificationService.token
    }

    /// Notification IDs opened during the current app session. These are merged
    /// with server read markers so the badge and unread tab update immediately.
    /// (`locallyReadNotificationIdsProvider`.)
    var locallyReadNotificationIds: StateBox<Set<String>> {
        let scope = provide { LocallyReadNotificationIdsScope() }
        let userId = notificationUserSelection.value?.id
        if let box = scope.box, scope.userId == userId { return box }
        let box = StateBox<Set<String>>([])
        scope.userId = userId
        scope.box = box
        return box
    }

    /// The server-backed feed, newest first as the API returns it.
    /// (`notificationRemoteListProvider`.)
    var notificationRemoteList: AsyncResource<[AppNotification]> {
        provide {
            let selection = notificationUserSelection
            return AsyncResource(dependencies: { AnyHashable(selection.value) }, loader: { [unowned self] in
                guard let user = selection.value else { return [] }
                let getNotifications = self.getNotificationsUseCase
                let items: [AppNotification] = try await self.authNotifier.withValidAccessToken { token in
                    let result = await getNotifications((accessToken: token, userId: user.id, role: user.role))
                    return try result.fold(
                        { (failure: AppFailure) -> [AppNotification] in throw ApiException(failure.message) },
                        { notifications in notifications }
                    )
                }
                // `ref.onDispose(() => active = false)`: a rebuild cancels this
                // load, and a cancelled load's result is discarded.
                if Task.isCancelled { return [] }
                return items
            })
        }
    }

    /// The full feed with both server and locally-opened messages marked as read.
    /// (`notificationListProvider`.)
    var notificationList: AsyncValue<[AppNotification]> {
        let locallyRead = locallyReadNotificationIds.value
        return notificationWhenData(notificationRemoteList.state) { items in
            items.map { item in locallyRead.contains(item.id) ? item.copyWith(read: true) : item }
        }
    }

    /// Marks one notification read immediately, then persists it for later visits.
    ///
    /// The local marker keeps the unread badge responsive. A successful insert
    /// refreshes `notificationRemoteList`, which queries
    /// `GetMyNotificationReads` again to reconcile with the server.
    /// (Dart's top-level `markNotificationRead(ref, notificationId)`.)
    func markNotificationRead(_ notificationId: String) async {
        if notificationId.isEmpty { return }
        let current = locallyReadNotificationIds.value
        if current.contains(notificationId) { return }
        locallyReadNotificationIds.value = current.union([notificationId])

        let useCase = markNotificationReadUseCase
        let result = await authNotifier.withValidAccessTokenResult { token in
            await useCase((accessToken: token, notificationId: notificationId))
        }
        if result.isSuccess {
            notificationRemoteList.invalidate()
        }
    }

    /// Unread count for the home-screen bell badge.
    /// (`unreadNotificationCountProvider`.)
    var unreadNotificationCount: Int {
        notificationList.maybeWhen(
            data: { items in items.filter { !$0.read }.count },
            orElse: { 0 }
        )
    }
}
