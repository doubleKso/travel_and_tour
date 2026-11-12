import SwiftUI

/// Flutter's `showDialog` / `showModalBottomSheet`, awaitable and returning
/// the value the modal was popped with.
///
/// ```swift
/// // final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
/// //   …, actions: [TextButton(onPressed: () => Navigator.pop(ctx, true), child: …)]));
/// let ok: Bool? = await showDialog { dismiss in
///     ConfirmCard(onConfirm: { dismiss(true) }, onCancel: { dismiss(false) })
/// }
///
/// // final picked = await showModalBottomSheet<TravelClass>(context: context,
/// //   isScrollControlled: true, builder: (ctx) => …);
/// let picked: TravelClass? = await showModalBottomSheet(isScrollControlled: true) { dismiss in
///     ClassPicker(onPick: { dismiss($0) })
/// }
/// ```
/// Inside the content, `@Environment(\.dismissModal)` pops the top modal from
/// any depth — Dart's `Navigator.pop(context, value)`.
///
/// Modals are drawn by `ModalHost` above the navigation stack. Pushing a
/// route from a modal therefore needs the modal dismissed first, which is
/// what the Dart code does with `Navigator.pop` before `context.router.push`.
@MainActor
@Observable
final class ModalCenter {
    static let shared = ModalCenter()

    enum Kind {
        case dialog
        case bottomSheet(SheetStyle)
    }

    struct SheetStyle {
        var isScrollControlled = false
        var backgroundColor: Color = AppColors.surface
        var topRadius: CGFloat = 28
        var showDragHandle = false
        var enableDrag = true
    }

    struct Entry: Identifiable {
        let id: UUID
        let kind: Kind
        let barrierDismissible: Bool
        let barrierColor: Color
        let content: AnyView
        /// Removes the entry and resumes the awaiting caller (once).
        let finish: (Any?) -> Void
    }

    private(set) var stack: [Entry] = []

    var isPresenting: Bool { !stack.isEmpty }

    func present<T>(
        kind: Kind,
        barrierDismissible: Bool,
        barrierColor: Color,
        content: (_ dismiss: @escaping (T?) -> Void) -> AnyView
    ) async -> T? {
        await withCheckedContinuation { (continuation: CheckedContinuation<T?, Never>) in
            let id = UUID()
            var resumed = false
            let finish: (Any?) -> Void = { [weak self] result in
                guard !resumed else { return }
                resumed = true
                withAnimation(.easeOut(duration: 0.2)) {
                    self?.stack.removeAll { $0.id == id }
                }
                continuation.resume(returning: result as? T)
            }
            let view = content { value in finish(value) }
            withAnimation(.easeOut(duration: 0.25)) {
                stack.append(Entry(
                    id: id,
                    kind: kind,
                    barrierDismissible: barrierDismissible,
                    barrierColor: barrierColor,
                    content: view,
                    finish: finish
                ))
            }
        }
    }

    /// Pops the top modal with `result` (Dart `Navigator.pop(context, result)`).
    func dismissTop(_ result: Any? = nil) {
        stack.last?.finish(result)
    }

    /// Pops every modal (e.g. before a `replaceAll`).
    func dismissAll() {
        for entry in stack.reversed() { entry.finish(nil) }
    }
}

/// Flutter `showDialog<T>`: a centred dialog over a dimmed barrier.
@MainActor
func showDialog<T, Content: View>(
    barrierDismissible: Bool = true,
    barrierColor: Color = Colors.black54,
    @ViewBuilder builder: @escaping (_ dismiss: @escaping (T?) -> Void) -> Content
) async -> T? {
    await ModalCenter.shared.present(
        kind: .dialog,
        barrierDismissible: barrierDismissible,
        barrierColor: barrierColor
    ) { dismiss in AnyView(builder(dismiss)) }
}

/// Flutter `showModalBottomSheet<T>`.
@MainActor
func showModalBottomSheet<T, Content: View>(
    isScrollControlled: Bool = false,
    isDismissible: Bool = true,
    enableDrag: Bool = true,
    showDragHandle: Bool = false,
    backgroundColor: Color = AppColors.surface,
    topRadius: CGFloat = 28,
    barrierColor: Color = Colors.black54,
    @ViewBuilder builder: @escaping (_ dismiss: @escaping (T?) -> Void) -> Content
) async -> T? {
    let style = ModalCenter.SheetStyle(
        isScrollControlled: isScrollControlled,
        backgroundColor: backgroundColor,
        topRadius: topRadius,
        showDragHandle: showDragHandle,
        enableDrag: enableDrag
    )
    return await ModalCenter.shared.present(
        kind: .bottomSheet(style),
        barrierDismissible: isDismissible,
        barrierColor: barrierColor
    ) { dismiss in AnyView(builder(dismiss)) }
}

/// `Navigator.pop(context, value)` from inside a modal's content.
struct DismissModalAction {
    let action: (Any?) -> Void
    func callAsFunction(_ result: Any? = nil) { action(result) }
}

private struct DismissModalKey: EnvironmentKey {
    static let defaultValue = DismissModalAction { _ in }
}

extension EnvironmentValues {
    var dismissModal: DismissModalAction {
        get { self[DismissModalKey.self] }
        set { self[DismissModalKey.self] = newValue }
    }
}

/// Draws the modal stack. Mounted once by `AppWidget` above the navigator.
struct ModalHost: View {
    @State private var center = ModalCenter.shared

    var body: some View {
        ZStack {
            ForEach(Array(center.stack.enumerated()), id: \.element.id) { index, entry in
                layer(for: entry).zIndex(Double(index))
            }
        }
        .animation(.easeOut(duration: 0.25), value: center.stack.map(\.id))
    }

    @ViewBuilder
    private func layer(for entry: ModalCenter.Entry) -> some View {
        let dismiss = DismissModalAction { entry.finish($0) }
        ZStack {
            entry.barrierColor
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { if entry.barrierDismissible { entry.finish(nil) } }
                .transition(.opacity)
            switch entry.kind {
            case .dialog:
                entry.content
                    .padding(.horizontal, 40)
                    .padding(.vertical, 24)
                    .environment(\.dismissModal, dismiss)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            case .bottomSheet(let style):
                BottomSheetContainer(style: style, onDismiss: { entry.finish(nil) }) {
                    entry.content.environment(\.dismissModal, dismiss)
                }
                .transition(.move(edge: .bottom))
            }
        }
    }
}

/// Material modal bottom sheet: anchored to the bottom, rounded top corners,
/// drag down to dismiss, height capped at 9/16 of the screen unless
/// `isScrollControlled`.
private struct BottomSheetContainer<Content: View>: View {
    let style: ModalCenter.SheetStyle
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer(minLength: style.isScrollControlled ? 0 : geometry.size.height * 7 / 16)
                VStack(spacing: 0) {
                    if style.showDragHandle {
                        Capsule()
                            .fill(AppColors.textTertiary.withValues(alpha: 0.4))
                            .frame(width: 32, height: 4)
                            .padding(.vertical, 22)
                    }
                    content()
                }
                .frame(maxWidth: .infinity)
                .background(
                    UnevenRoundedRectangle(
                        cornerRadii: BorderRadius.vertical(top: style.topRadius),
                        style: .continuous
                    )
                    .fill(style.backgroundColor)
                    .ignoresSafeArea(edges: .bottom)
                )
                .offset(y: max(0, dragOffset))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            guard style.enableDrag else { return }
                            dragOffset = value.translation.height
                        }
                        .onEnded { value in
                            guard style.enableDrag else { return }
                            if value.translation.height > 120 || value.predictedEndTranslation.height > 300 {
                                onDismiss()
                            } else {
                                withAnimation(.spring(duration: 0.25)) { dragOffset = 0 }
                            }
                        }
                )
            }
        }
    }
}
