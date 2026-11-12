import SwiftUI
import FirebaseCore

/// Entry point for every flavor — the port of lib/main.dart and
/// lib/app/bootstrap/bootstrap.dart.
///
/// Only three things belong here: configure what must exist before the first
/// view (Firebase, preferences, the cached session, the language), build the
/// composition root, and install the root view. The flavor comes from the
/// scheme's build configuration (see `F`).
@main
struct EpicWorldApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var container: AppContainer

    init() {
        // The flavor's GoogleService-Info.plist is copied into the bundle by
        // the "Copy flavor GoogleService-Info.plist" build phase.
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
        // Theme and locale preferences plus the Keychain session cache are
        // read before any object that depends on them is created.
        AppPrefs.initialize()
        SecureSessionStore.initialize()
        _ = LocaleStore.shared
        _container = State(initialValue: AppContainer())
    }

    var body: some Scene {
        WindowGroup {
            AppWidget()
                .environment(container)
        }
    }
}
