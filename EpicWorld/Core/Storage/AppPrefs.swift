import Foundation

/// Synchronous preferences façade — the port of `app_storage`'s `AppPrefs`.
///
/// Values live in `UserDefaults` under the `flutter.` prefix that
/// `shared_preferences` uses on iOS, so the native build reads everything the
/// Flutter build saved (language, remembered email, profile mirror …).
///
/// UserDefaults is ready synchronously, so Dart's `await AppPrefs.init()` has
/// no equivalent work; `initialize()` exists only to keep startup readable.
enum AppPrefs {
    static let prefix = "flutter."

    /// Swappable for tests (`UserDefaults(suiteName:)`).
    static var store: UserDefaults = .standard

    static func initialize() {}

    static var isReady: Bool { true }

    private static func key(_ name: String) -> String { prefix + name }

    static func getString(_ name: String, defaultValue: String = "") -> String {
        store.string(forKey: key(name)) ?? defaultValue
    }

    static func getBool(_ name: String, defaultValue: Bool = false) -> Bool {
        guard let value = store.object(forKey: key(name)) else { return defaultValue }
        return Dart.bool(value) ?? (value as? Bool) ?? defaultValue
    }

    static func getInt(_ name: String, defaultValue: Int = 0) -> Int {
        guard let value = store.object(forKey: key(name)), Dart.isInt(value) else { return defaultValue }
        return Dart.int(value) ?? defaultValue
    }

    static func getDouble(_ name: String, defaultValue: Double = 0) -> Double {
        guard let value = store.object(forKey: key(name)), Dart.isNum(value) else { return defaultValue }
        return Dart.double(value) ?? defaultValue
    }

    /// The raw stored string list (`getStringList`).
    static func getStringList(_ name: String) -> [String]? {
        store.stringArray(forKey: key(name))
    }

    static func contains(_ name: String) -> Bool {
        store.object(forKey: key(name)) != nil
    }

    static func setString(_ name: String, _ value: String) {
        store.set(value, forKey: key(name))
    }

    static func setBool(_ name: String, _ value: Bool) {
        store.set(value, forKey: key(name))
    }

    static func setInt(_ name: String, _ value: Int) {
        store.set(value, forKey: key(name))
    }

    static func setDouble(_ name: String, _ value: Double) {
        store.set(value, forKey: key(name))
    }

    static func setStringList(_ name: String, _ value: [String]) {
        store.set(value, forKey: key(name))
    }

    static func remove(_ name: String) {
        store.removeObject(forKey: key(name))
    }

    /// Removes every app preference (only `flutter.`-prefixed keys, as
    /// `SharedPreferences.clear()` does).
    static func clear() {
        for name in store.dictionaryRepresentation().keys where name.hasPrefix(prefix) {
            store.removeObject(forKey: name)
        }
    }
}
