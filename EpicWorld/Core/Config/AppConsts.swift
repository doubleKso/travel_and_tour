import Foundation

/// Keys and fixed values shared across the app — the port of
/// lib/core/config/app_consts.dart.
///
/// Every preference key lives here so a rename is a single edit and two
/// features can never disagree about a key's spelling. `AppPrefs` stores them
/// under the same `flutter.`-prefixed UserDefaults keys the Flutter app used,
/// so a user upgrading from the Flutter build keeps their settings.
enum AppConsts {
    // ---- Preference keys ---------------------------------------------------
    static let keyUserName = "user_name"
    static let keyUserEmail = "user_email"
    static let keyUserPhone = "user_phone"
    static let keyUserId = "user_id"
    static let keyUserDisplayName = "user_display_name"
    static let keyUserAvatarUrl = "user_avatar_url"
    static let keyUserPoints = "user_points"
    static let keyUserRole = "user_role"
    static let keyRememberedEmail = "remembered_email"
    static let keyRememberedPassword = "remembered_password"
    static let keyLocale = "app_locale"
    static let keyDarkMode = "dark_mode"
    static let keyFirstRun = "first_run"
    static let keyOnboardingSeen = "onboarding_seen"

    // ---- Locale values -----------------------------------------------------
    static let localeEn = "en"
    static let localeMy = "my"

    // ---- Contact -----------------------------------------------------------
    // Stored as printed. `ContactLauncher` strips the spacing before dialling,
    // so the same constant drives both the label and the tap-to-call.
    static let hotlinePhone = "+95 9 787 844 882"
    static let officeMobile = "+95 9 4500 12345"
    static let officeLandline = "+95 1 234 5678"
    static let messengerPage = "epicworldtravel"

    // ---- Networking --------------------------------------------------------
    static let connectTimeout: TimeInterval = 30
    static let receiveTimeout: TimeInterval = 30
}
