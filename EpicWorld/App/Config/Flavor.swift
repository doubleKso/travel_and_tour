import Foundation

enum Flavor: String, CaseIterable {
    case prod, uat, qa
}

/// Build-time configuration — the port of lib/app/config/flavors.dart.
///
/// The flavor comes from the scheme: each flavor's xcconfig sets
/// `APP_FLAVOR`, which Info.plist exposes as `AppFlavor` (Flutter reads the
/// same value from `appFlavor`). Anything that differs between prod / uat / qa
/// belongs here, reading its values from `Env` — never hard-code a URL at a
/// call site.
enum F {
    /// Set once from Info.plist; tests may assign it.
    static var appFlavor: Flavor = {
        let raw = Bundle.main.object(forInfoDictionaryKey: "AppFlavor") as? String ?? ""
        return Flavor(rawValue: raw) ?? .prod
    }()

    static var name: String { appFlavor.rawValue }

    static var title: String {
        switch appFlavor {
        case .prod: return "Epic World"
        case .uat: return "Epic World(UAT)"
        case .qa: return "Epic World(QA)"
        }
    }

    /// REST API host for the running flavor.
    static var apiBaseUrl: String {
        switch appFlavor {
        case .prod: return Env.prodApiBaseUrl
        case .uat: return Env.uatApiBaseUrl
        case .qa: return Env.qaApiBaseUrl
        }
    }

    /// Firebase Functions host for the running flavor.
    static var functionsBaseUrl: String {
        switch appFlavor {
        case .prod: return Env.prodFunctionsBaseUrl
        case .uat: return Env.uatFunctionsBaseUrl
        case .qa: return Env.qaFunctionsBaseUrl
        }
    }

    /// Resolves a callable endpoint path against the selected Functions host.
    static func functionsUrl(_ endpoint: String) -> String {
        let base = functionsBaseUrl.replacingOccurrences(of: #"/+$"#, with: "", options: .regularExpression)
        let path = endpoint.replacingOccurrences(of: #"^/+"#, with: "", options: .regularExpression)
        return "\(base)/\(path)"
    }

    /// Show the corner flavor ribbon everywhere except production.
    static var showFlavorBanner: Bool { appFlavor != .prod }
}
