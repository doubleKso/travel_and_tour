import SwiftUI
import UIKit

/// The app's navigator — the port of auto_route's `StackRouter` as the Dart
/// pages use it.
///
/// `root` is the bottom of the stack (Welcome until `replaceAll`), `path` the
/// routes pushed on top of it (bound to the `NavigationStack`), and `overlay`
/// the one transparent route (`flightSearchLoading`) drawn above everything.
@MainActor
@Observable
final class AppRouter {
    /// One stack slot: a route plus the identity SwiftUI navigates by.
    struct Entry: Hashable, Identifiable {
        let id: UUID
        let route: Route

        init(_ route: Route) {
            id = UUID()
            self.route = route
        }

        static func == (lhs: Entry, rhs: Entry) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    /// A page's `PopScope(canPop:, onPopInvokedWithResult:)`.
    struct PopGuard {
        let canPop: Bool
        let onPopInvoked: (_ didPop: Bool) -> Void
    }

    /// The router the UIKit back-swipe hook consults.
    private(set) static weak var shared: AppRouter?

    private(set) var root = Entry(.welcome())
    private(set) var path: [Entry] = []
    private(set) var overlay: Entry?

    @ObservationIgnored private var results: [UUID: (Any?) -> Void] = [:]
    @ObservationIgnored private var guards: [UUID: PopGuard] = [:]

    init() {
        AppRouter.shared = self
    }

    // MARK: - State

    var entries: [Entry] { [root] + path + (overlay.map { [$0] } ?? []) }

    /// Routes from bottom to top (`router.stack`).
    var stack: [Route] { entries.map(\.route) }

    /// The top-most route (`router.current`).
    var current: Route { entries.last!.route }

    /// `router.current.name`.
    var currentName: String { current.name }

    /// `router.currentPath`.
    var currentPath: String { current.path }

    /// `router.canPop()`.
    var canPop: Bool { overlay != nil || !path.isEmpty }

    var topEntryID: UUID { entries.last!.id }

    // MARK: - Navigation

    /// `router.push(route)` without waiting.
    func push(_ route: Route) {
        insert(Entry(route))
    }

    /// `await router.push<T>(route)`: resolves with the value the route is
    /// popped with, or nil when it is dismissed any other way.
    func pushForResult<T>(_ route: Route, as type: T.Type = T.self) async -> T? {
        await withCheckedContinuation { (continuation: CheckedContinuation<T?, Never>) in
            let entry = Entry(route)
            results[entry.id] = { continuation.resume(returning: $0 as? T) }
            insert(entry)
        }
    }

    /// `await router.push(route)` used only to wait until the route is gone.
    func pushAndWait(_ route: Route) async {
        let _: Any? = await pushForResult(route, as: Any.self)
    }

    /// `router.pop(result)` — pops unconditionally (guards are not asked).
    func pop(_ result: Any? = nil) {
        if let overlay {
            withAnimation(.easeOut(duration: 0.25)) { self.overlay = nil }
            finish(overlay.id, result)
            return
        }
        guard let top = path.last else { return }
        path.removeLast()
        finish(top.id, result)
    }

    /// `router.maybePop(result)` / the back button: asks the top route's
    /// `popScope` first. Returns whether a route was popped.
    @discardableResult
    func maybePop(_ result: Any? = nil) async -> Bool {
        guard canPop else { return false }
        let topID = topEntryID
        if let popGuard = guards[topID] {
            guard popGuard.canPop else {
                popGuard.onPopInvoked(false)
                return false
            }
            pop(result)
            popGuard.onPopInvoked(true)
            return true
        }
        pop(result)
        return true
    }

    /// `router.replace(route)`: swaps the top route.
    func replace(_ route: Route) {
        if overlay != nil {
            pop()
        }
        if let top = path.last {
            path.removeLast()
            finish(top.id, nil)
            insert(Entry(route))
        } else {
            replaceAll([route])
        }
    }

    /// `router.replaceAll(routes)`: the stack becomes exactly `routes`.
    func replaceAll(_ routes: [Route]) {
        guard let first = routes.first else { return }
        ModalCenter.shared.dismissAll()
        let removed = entries
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            overlay = nil
            root = Entry(first)
            path = routes.dropFirst().map(Entry.init)
        }
        removed.forEach { finish($0.id, nil) }
    }

    /// `router.navigate(route)`: pops back to an existing route with the same
    /// name if there is one, otherwise pushes.
    func navigate(_ route: Route) {
        if root.route.name == route.name && path.isEmpty && overlay == nil { return }
        if let index = path.lastIndex(where: { $0.route.name == route.name }) {
            popTo(index: index)
        } else if root.route.name == route.name {
            popUntilRoot()
        } else {
            push(route)
        }
    }

    /// `router.popUntilRoot()`.
    func popUntilRoot() {
        if overlay != nil { pop() }
        let removed = path
        path.removeAll()
        removed.reversed().forEach { finish($0.id, nil) }
    }

    /// `router.popUntil((route) => predicate)`.
    func popUntil(_ predicate: (Route) -> Bool) {
        if let overlay, !predicate(overlay.route) { pop() }
        while let top = path.last, !predicate(top.route) {
            path.removeLast()
            finish(top.id, nil)
        }
    }

    /// `router.popUntilRouteWithName(name)`.
    func popUntilRouteWithName(_ name: String) {
        popUntil { $0.name == name }
    }

    /// Called by the `NavigationStack` binding when the user swipes back or
    /// the system pops.
    func setPath(_ newPath: [Entry]) {
        let kept = Set(newPath.map(\.id))
        let removed = path.filter { !kept.contains($0.id) }
        path = newPath
        removed.forEach { entry in
            finish(entry.id, nil)
            guards[entry.id]?.onPopInvoked(true)
        }
    }

    // MARK: - PopScope

    func registerGuard(_ entryID: UUID, canPop: Bool, onPopInvoked: @escaping (Bool) -> Void) {
        guards[entryID] = PopGuard(canPop: canPop, onPopInvoked: onPopInvoked)
    }

    func unregisterGuard(_ entryID: UUID) {
        guards[entryID] = nil
    }

    /// Whether the interactive back-swipe may start on the top route.
    var topAllowsSwipeBack: Bool {
        guard overlay == nil, let top = path.last else { return false }
        return guards[top.id]?.canPop ?? true
    }

    // MARK: - Private

    private func insert(_ entry: Entry) {
        if entry.route.isOverlay {
            if let previous = overlay { finish(previous.id, nil) }
            withAnimation(.easeIn(duration: 0.4)) { overlay = entry }
        } else {
            path.append(entry)
        }
    }

    private func popTo(index: Int) {
        if overlay != nil { pop() }
        while path.count > index + 1, let top = path.last {
            path.removeLast()
            finish(top.id, nil)
        }
    }

    private func finish(_ id: UUID, _ result: Any?) {
        guards[id] = nil
        results.removeValue(forKey: id)?(result)
    }
}

// MARK: - Route identity in the environment

private struct RouteEntryIDKey: EnvironmentKey {
    static let defaultValue: UUID? = nil
}

extension EnvironmentValues {
    /// The stack entry the current view belongs to (set by `RouteView`).
    var routeEntryID: UUID? {
        get { self[RouteEntryIDKey.self] }
        set { self[RouteEntryIDKey.self] = newValue }
    }
}

// MARK: - PopScope

private struct PopScopeModifier: ViewModifier {
    let canPop: Bool
    let onPopInvoked: (Bool) -> Void

    @Environment(\.routeEntryID) private var entryID
    @Environment(AppRouter.self) private var router

    func body(content: Content) -> some View {
        content
            .onAppear(perform: register)
            .onChange(of: canPop) { register() }
    }

    private func register() {
        guard let entryID else { return }
        router.registerGuard(entryID, canPop: canPop, onPopInvoked: onPopInvoked)
    }
}

extension View {
    /// Flutter's `PopScope(canPop:, onPopInvokedWithResult:)`: when `canPop`
    /// is false the back button and the back-swipe are blocked and
    /// `onPopInvoked(false)` runs instead (e.g. to show a "leave checkout?"
    /// dialog). After a permitted pop it runs with `true`.
    func popScope(canPop: Bool, onPopInvoked: @escaping (_ didPop: Bool) -> Void = { _ in }) -> some View {
        modifier(PopScopeModifier(canPop: canPop, onPopInvoked: onPopInvoked))
    }
}

// MARK: - Back-swipe with hidden navigation bars

/// Pages hide the system navigation bar and draw a Material `AppBar`, which
/// would otherwise switch off the interactive back-swipe Flutter keeps on
/// iOS. This restores it and lets `popScope` veto it.
extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === interactivePopGestureRecognizer, viewControllers.count > 1 else {
            return gestureRecognizer !== interactivePopGestureRecognizer
        }
        return MainActor.assumeIsolated { AppRouter.shared?.topAllowsSwipeBack ?? true }
    }
}
