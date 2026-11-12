// Port of lib/features/notification/presentation/pages/notifications_page.dart

import SwiftUI

/// NOTIFICATIONS — a "Latest" (all) and "Unread" tabbed feed.
struct NotificationsPage: View {
    @Environment(AppContainer.self) private var container

    /// `DefaultTabController` index.
    @State private var selectedTab = 0
    @State private var didFetchOnEntry = false

    init() {}

    var body: some View {
        let notificationState = container.notificationList
        let all = notificationState.valueOrNull ?? []
        let unread = all.filter { !$0.read }

        Scaffold(backgroundColor: AppColors.surface, appBar: {
            VStack(spacing: 0) {
                AppBar(
                    title: LocaleKeys.notification_notifications.tr(),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    centerTitle: true
                )
                NotificationTabBar(
                    labels: [
                        LocaleKeys.notification_latest.tr(),
                        LocaleKeys.notification_unread.tr(args: ["\(unread.count)"]),
                    ],
                    selected: $selectedTab
                )
            }
        }) {
            if notificationState.isLoading {
                ProgressView()
                    .tint(AppColors.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = notificationState.error {
                NotificationError(message: String(describing: error))
            } else {
                // TabBarView: swipe between the two lists.
                TabView(selection: $selectedTab) {
                    NotificationList(items: all)
                        .tag(0)
                    NotificationList(items: unread, emptyMessage: "No unread notifications.")
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .onAppear {
            // The bell navigates here; fetching on every entry keeps the latest
            // notifications and read markers in sync with the server.
            // (`initState` post-frame callback — once per page.)
            guard !didFetchOnEntry else { return }
            didFetchOnEntry = true
            container.notificationRemoteList.invalidate()
        }
    }
}

/// The app bar's `TabBar`: white labels over the brand green, a 3pt white
/// indicator under the selected label (Material 3 primary tabs size the
/// indicator to the label), and the M3 divider along the bottom.
private struct NotificationTabBar: View {
    let labels: [String]
    @Binding var selected: Int

    @Namespace var indicator

    /// Material 3 `outlineVariant` for the brand seed (TabBar divider).
    private static let dividerColor = Color(0xFFC3C8BB)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                tab(index: index, label: label)
            }
        }
        .frame(height: 48)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Self.dividerColor).frame(height: 1)
        }
        .background(AppColors.primary)
        .animation(.easeInOut(duration: 0.3), value: selected)
    }

    private func tab(index: Int, label: String) -> some View {
        let isSelected = index == selected
        let style = isSelected
            ? AppTypography.body(14, weight: .w700, color: Colors.white)
            : AppTypography.body(14, color: Colors.white.withValues(alpha: 0.7))
        return Button {
            selected = index
        } label: {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Text(label)
                    .textStyle(style)
                    .lineLimit(1)
                Spacer(minLength: 0)
                // Indicator sized to the label.
                Text(label)
                    .textStyle(style)
                    .lineLimit(1)
                    .hidden()
                    .frame(height: 3)
                    .overlay {
                        if isSelected {
                            UnevenRoundedRectangle(cornerRadii: BorderRadius.only(topLeft: 3, topRight: 3))
                                .fill(Colors.white)
                                .matchedGeometryEffect(id: "indicator", in: indicator)
                        }
                    }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct NotificationError: View {
    let message: String

    var body: some View {
        Text(message)
            .textStyle(AppTypography.body(14, color: AppColors.textSecondary))
            .multilineTextAlignment(.center)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NotificationList: View {
    let items: [AppNotification]
    var emptyMessage = "No notifications yet."

    @Environment(AppContainer.self) var container

    var body: some View {
        if items.isEmpty {
            VStack(spacing: 0) {
                Icon(Icons.notifications_off_outlined, size: 56, color: AppColors.textTertiary)
                VGap(14)
                Text(emptyMessage)
                    .textStyle(AppTypography.body(14, color: AppColors.textSecondary))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { VGap(12) }
                        NotificationTile(item: item) {
                            Task { await container.markNotificationRead(item.id) }
                        }
                    }
                }
                .padding(16)
            }
        }
    }
}

private struct NotificationTile: View {
    let item: AppNotification
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Icon(item.icon, size: 22, color: item.color)
                .frame(width: 44, height: 44)
                .boxDecoration(color: item.color.withValues(alpha: 0.12), radius: 13)
            HGap(12)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Text(item.title)
                        .textStyle(AppTypography.heading(14.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !item.read {
                        Circle()
                            .fill(AppColors.accent)
                            .frame(width: 8, height: 8)
                            .padding(.leading, 6)
                            .padding(.top, 4)
                    }
                }
                VGap(3)
                Text(item.body)
                    .textStyle(AppTypography.body(12.5, color: AppColors.textSecondary, height: 1.35))
                VGap(6)
                Text(item.time)
                    .textStyle(AppTypography.body(11, color: AppColors.textPrimary))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .boxDecoration(
            color: item.read ? AppColors.surface : AppColors.primarySurface.withValues(alpha: 0.5),
            radius: 16,
            borderColor: item.read ? AppColors.border : AppColors.primary.withValues(alpha: 0.25)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            // `onTap: item.read ? null : onTap`.
            if !item.read { onTap() }
        }
    }
}
