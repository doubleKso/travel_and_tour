import SwiftUI

/// App-wide snack bars — Flutter's `ScaffoldMessenger`.
///
/// ```swift
/// // ScaffoldMessenger.of(context)
/// //   ..hideCurrentSnackBar()
/// //   ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
/// SnackBarCenter.shared.show(msg, floating: true)
/// ```
/// `show` replaces the current snack bar, so `hideCurrentSnackBar()` before it
/// needs no separate call. `SnackBarHost` (mounted by `AppWidget`) draws it
/// above every route, sheet and dialog, as Flutter's root messenger does.
@MainActor
@Observable
final class SnackBarCenter {
    static let shared = SnackBarCenter()

    struct Item: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let actionLabel: String?
        let action: (() -> Void)?
        let backgroundColor: Color?
        let textColor: Color?
        let floating: Bool
        let duration: Duration

        static func == (lhs: Item, rhs: Item) -> Bool { lhs.id == rhs.id }
    }

    private(set) var current: Item?
    @ObservationIgnored private var dismissTask: Task<Void, Never>?

    func show(
        _ message: String,
        actionLabel: String? = nil,
        action: (() -> Void)? = nil,
        backgroundColor: Color? = nil,
        textColor: Color? = nil,
        floating: Bool = false,
        duration: Duration = .seconds(4)
    ) {
        let item = Item(
            message: message,
            actionLabel: actionLabel,
            action: action,
            backgroundColor: backgroundColor,
            textColor: textColor,
            floating: floating,
            duration: duration
        )
        dismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.25)) { current = item }
        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled, self?.current?.id == item.id else { return }
            self?.hideCurrentSnackBar()
        }
    }

    func hideCurrentSnackBar() {
        dismissTask?.cancel()
        withAnimation(.easeIn(duration: 0.2)) { current = nil }
    }
}

/// Draws `SnackBarCenter.shared.current` — Material 3 colours and shape.
struct SnackBarHost: View {
    @State private var center = SnackBarCenter.shared

    /// Material 3 `inverseSurface` / `onInverseSurface` for the brand seed.
    private static let background = Color(0xFF2F312C)
    private static let foreground = Color(0xFFF0F1EA)
    private static let actionColor = Color(0xFFB1D49E)

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            if let item = center.current {
                bar(item)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(item.id)
            }
        }
        .animation(.easeOut(duration: 0.25), value: center.current)
    }

    private func bar(_ item: SnackBarCenter.Item) -> some View {
        HStack(spacing: 0) {
            Text(item.message)
                .textStyle(AppTypography.body(14, color: item.textColor ?? Self.foreground))
                .frame(maxWidth: .infinity, alignment: .leading)
            if let label = item.actionLabel {
                Button(label) {
                    item.action?()
                    center.hideCurrentSnackBar()
                }
                .buttonStyle(TextButtonStyle(foregroundColor: Self.actionColor))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, item.actionLabel == nil ? 14 : 4)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: item.floating ? 4 : 0)
                .fill(item.backgroundColor ?? Self.background)
                .shadow(color: Colors.black.withValues(alpha: 0.25), radius: 4, y: 2)
                .ignoresSafeArea(edges: item.floating ? [] : .bottom)
        )
        .padding(item.floating ? EdgeInsets(top: 5, leading: 15, bottom: 10, trailing: 15) : EdgeInsets())
        .onTapGesture { center.hideCurrentSnackBar() }
    }
}
