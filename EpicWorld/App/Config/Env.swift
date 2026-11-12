import Foundation

/// Per-environment constants consumed by `F` — the port of
/// lib/app/config/env.dart.
///
/// Dart overrides these with `--dart-define`. Here an override is an
/// Info.plist key of the same name (fed from a build setting in the flavor's
/// xcconfig); the committed default applies when the key is absent or empty.
/// Keep secrets out of this file — it is committed.
enum Env {
    /// Google OAuth web client. The backend verifies Google ID tokens against
    /// this audience (`serverClientID` for Google Sign-In).
    static let googleWebClientId = value(
        "EPIC_GOOGLE_WEB_CLIENT_ID",
        default: "75564183650-r89jlpjrridd0c1jdpd1t88b5m0tb4gt.apps.googleusercontent.com"
    )

    /// REST API bases used by `AuthRemoteService`.
    static let prodApiBaseUrl = value("EPIC_PROD_API_BASE_URL", default: "https://epic-world-admin.web.app/admin/api/v1")
    static let uatApiBaseUrl = value("EPIC_UAT_API_BASE_URL", default: "https://epic-world-admin.web.app/admin/api/v1")
    static let qaApiBaseUrl = value("EPIC_QA_API_BASE_URL", default: "https://epic-world-admin.web.app/admin/api/v1")

    /// Firebase Callable Functions bases. A flavor can point at a different
    /// Firebase project without changing any feature endpoint paths.
    static let prodFunctionsBaseUrl = value(
        "EPIC_PROD_FUNCTIONS_BASE_URL",
        default: "https://asia-southeast1-epicworld-fad26.cloudfunctions.net"
    )
    static let uatFunctionsBaseUrl = value(
        "EPIC_UAT_FUNCTIONS_BASE_URL",
        default: "https://asia-southeast1-epicworld-fad26.cloudfunctions.net"
    )
    static let qaFunctionsBaseUrl = value(
        "EPIC_QA_FUNCTIONS_BASE_URL",
        default: "https://asia-southeast1-epicworld-fad26.cloudfunctions.net"
    )

    private static func value(_ key: String, default fallback: String) -> String {
        let raw = (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // An unset build setting reaches Info.plist as "" or "$(KEY)".
        return raw.isEmpty || raw.hasPrefix("$(") ? fallback : raw
    }
}
