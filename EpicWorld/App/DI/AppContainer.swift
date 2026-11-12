import Foundation
import Observation

/// The composition root — what Riverpod's `ProviderScope` and the feature
/// `*_module.dart` / `*_providers.dart` files are in the Flutter app.
///
/// Every Riverpod provider becomes a property on `AppContainer`, declared in
/// that feature's `DI/` folder as an extension. The naming rule is mechanical
/// — drop the `Provider` suffix — so features reference each other exactly as
/// the Dart code does:
///
/// | Dart                                              | Swift                               |
/// |---------------------------------------------------|-------------------------------------|
/// | `final authRepositoryProvider = Provider<AuthRepository>((ref) => …)` | `var authRepository: AuthRepository { provide { … } }` |
/// | `final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>(…)` | `var authNotifier: AuthNotifier { provide { … } }` |
/// | `final hotelListProvider = FutureProvider<…>(…)`  | `var hotelList: AsyncResource<…> { provide { AsyncResource { … } } }` |
/// | `final xProvider = StateProvider<int>((ref) => 0)`| `var x: StateBox<Int> { provide { StateBox(0) } }` |
/// | `final fooProvider = Provider<bool>((ref) => ref.watch(a).b)` (derived) | `var foo: Bool { a.state.b }` (computed, not cached) |
/// | `ref.watch(p)` / `ref.read(p)`                    | `container.p` (observation tracks reads in views) |
/// | `ref.read(p.notifier).doThing()`                  | `container.p.doThing()`             |
/// | `ref.invalidate(futureProvider)`                  | `container.futureProvider.invalidate()` |
/// | `ref.invalidate(notifierProvider)`                | `container.reset("notifierName")`   |
/// | `ProviderScope(overrides: [p.overrideWithValue(v)])` | `container.override("p", with: v)` |
///
/// Views read it with `@Environment(AppContainer.self) private var container`.
@MainActor
@Observable
final class AppContainer {
    /// The live container, for the few UIKit entry points (app delegate,
    /// notification callbacks) that cannot reach the SwiftUI environment.
    private(set) static weak var current: AppContainer?

    @ObservationIgnored private var instances: [String: Any] = [:]

    init() {
        AppContainer.current = self
    }

    /// Returns the instance cached under `key` (the calling property's name),
    /// creating it with `make` on first use — a Riverpod provider that is
    /// kept alive.
    func provide<T>(_ key: String = #function, _ make: () -> T) -> T {
        if let existing = instances[key] as? T { return existing }
        let value = make()
        instances[key] = value
        return value
    }

    /// Drops a cached instance so the next read rebuilds it
    /// (`ref.invalidate` of a non-future provider).
    func reset(_ key: String) {
        instances[key] = nil
    }

    /// Replaces a provider's value — test overrides.
    func override<T>(_ key: String, with value: T) {
        instances[key] = value
    }

    // MARK: - Core (lib/core/providers/core_providers.dart)

    var router: AppRouter { provide { AppRouter() } }

    /// `FirebaseFunctions.instance` — the callable client every callable
    /// service is built with.
    var functions: CallableInvoking { provide { CallableClient() as CallableInvoking } }

    /// `dioProvider` — the shared REST client.
    var http: HTTPClient {
        provide {
            HTTPClient(
                baseURL: F.apiBaseUrl,
                accessToken: { SecureSessionStore.accessToken },
                languageCode: { L10n.currentCode }
            )
        }
    }

    /// `appReadyProvider` — flips to true once start-up has finished.
    var appReady: StateBox<Bool> { provide { StateBox(false) } }

    /// `appLogoutProvider` — set from anywhere to force a sign-out with a reason.
    var appLogout: StateBox<String> { provide { StateBox("") } }

    /// `mainShellTabProvider` — selected bottom-navigation tab in
    /// `MainShellPage` (0 Home, 1 Member, 2 History, 3 Profile/Login). Any flow
    /// can land the user on a tab: `container.mainShellTab.value = 2`.
    var mainShellTab: StateBox<Int> { provide { StateBox(0) } }

    /// `themeModeProvider`. The app ships one light palette (the Flutter dark
    /// theme is the light theme too), so this only persists the preference.
    var themeMode: StateBox<ThemeMode> {
        provide { StateBox(AppPrefs.getBool(AppConsts.keyDarkMode) ? .dark : .light) }
    }

    /// `saveThemeMode(ref, mode)`.
    func saveThemeMode(_ mode: ThemeMode) {
        themeMode.value = mode
        AppPrefs.setBool(AppConsts.keyDarkMode, mode == .dark)
    }
}

/// Flutter's `ThemeMode`.
enum ThemeMode: String {
    case system, light, dark
}
