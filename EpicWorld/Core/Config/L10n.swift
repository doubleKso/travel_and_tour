import Foundation
import Observation

/// The active language and its translations — what easy_localization's
/// controller does in the Flutter app.
///
/// Translations are the Flutter app's own `assets/l10n/<code>.json` files
/// (copied by scripts/sync_resources.sh), flattened to the dotted keys in
/// `LocaleKeys`. Because this object is `@Observable` and `tr()` reads
/// `code`, every view that rendered a translation re-renders when the
/// language changes — the job `LocaleScope` does in Flutter — while view
/// state, scroll offsets and the navigation stack stay put.
@Observable
final class LocaleStore {
    static let shared = LocaleStore()

    /// The active language code (`en` / `my`).
    private(set) var code: String

    @ObservationIgnored private var bundles: [String: [String: String]] = [:]

    private init() {
        code = L10n.resolveStartLocale()
        // Mirror the resolved language so `HTTPClient` sends the matching
        // `accept-language`, including a locale that came from the device.
        if AppPrefs.getString(AppConsts.keyLocale) != code {
            AppPrefs.setString(AppConsts.keyLocale, code)
        }
    }

    func setLocale(_ newCode: String) {
        guard L10n.supported.contains(newCode) else { return }
        code = newCode
    }

    /// The translation for `key` in the active language, or nil when missing.
    func translate(_ key: String) -> String? {
        let active = code // observation: re-render on language change
        return bundle(for: active)[key]
    }

    private func bundle(for code: String) -> [String: String] {
        if let cached = bundles[code] { return cached }
        let loaded = Self.load(code)
        bundles[code] = loaded
        return loaded
    }

    private static func load(_ code: String) -> [String: String] {
        guard let url = Bundle.main.url(forResource: code, withExtension: "json", subdirectory: "l10n"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) else { return [:] }
        var flat: [String: String] = [:]
        flatten(root, prefix: "", into: &flat)
        return flat
    }

    private static func flatten(_ node: Any, prefix: String, into flat: inout [String: String]) {
        if let map = Dart.map(node) {
            for (key, value) in map {
                flatten(value, prefix: prefix.isEmpty ? key : "\(prefix).\(key)", into: &flat)
            }
        } else if let text = Dart.str(node) {
            flat[prefix] = text
        }
    }
}

/// Localization setup — the port of lib/core/config/l10n.dart.
///
/// ```swift
/// Text(LocaleKeys.common_home.tr())                       // Dart: LocaleKeys.common_home.tr()
/// LocaleKeys.booking_select.tr(args: [title])             // Dart: ….tr(args: [title])
/// L10n.change(L10n.myanmar)                               // Dart: L10n.change(context, L10n.myanmar)
/// ```
enum L10n {
    static let english = AppConsts.localeEn
    static let myanmar = AppConsts.localeMy

    /// Languages the app ships translations for.
    static let supported = [english, myanmar]

    /// Used when neither a saved choice nor the device language is supported.
    static let fallback = english

    /// easy_localization's own persisted choice (`SharedPreferences` key
    /// `locale`), read so an upgrade from the Flutter build keeps the language.
    private static let easyLocalizationKey = "locale"

    /// Switches the app language, persisting it where easy_localization did
    /// and mirroring it for the `accept-language` header.
    static func change(_ code: String) {
        LocaleStore.shared.setLocale(code)
        AppPrefs.setString(easyLocalizationKey, code)
        AppPrefs.setString(AppConsts.keyLocale, code)
    }

    /// The active language code, safe to call from anywhere.
    static var currentCode: String {
        AppPrefs.getString(AppConsts.keyLocale, defaultValue: AppConsts.localeEn)
    }

    /// The active language for SwiftUI's `\.locale`.
    static var locale: Locale { Locale(identifier: LocaleStore.shared.code) }

    /// easy_localization's start-up choice: the saved locale, else the device
    /// language when supported, else `fallback`.
    static func resolveStartLocale() -> String {
        let saved = AppPrefs.getString(easyLocalizationKey)
        let savedCode = String(saved.split(whereSeparator: { $0 == "_" || $0 == "-" }).first ?? "")
        if supported.contains(savedCode) { return savedCode }
        for preferred in Locale.preferredLanguages {
            let language = Locale(identifier: preferred).language.languageCode?.identifier ?? ""
            if supported.contains(language) { return language }
        }
        return fallback
    }
}

extension String {
    /// easy_localization's `tr()`: the translation of this key in the active
    /// language with each `{}` replaced by the next of `args`. A missing key
    /// returns the key itself, as easy_localization does.
    func tr(args: [String] = []) -> String {
        var text = LocaleStore.shared.translate(self) ?? self
        for arg in args {
            guard let range = text.range(of: "{}") else { break }
            text.replaceSubrange(range, with: arg)
        }
        return text
    }
}
