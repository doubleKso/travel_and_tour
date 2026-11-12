import UIKit

/// Hands a phone number, email or chat link to another app — the port of
/// lib/core/utils/contact_launcher.dart.
///
/// Numbers are stored the way they are printed — `+95 9 787 844 882` — so
/// this is the one place that knows how to turn a readable number into a
/// `tel:` URI. When nothing answers (a simulator, an iPad without telephony)
/// the value is shown in a snack bar so it can still be read and copied.
@MainActor
enum ContactLauncher {
    private static let viberDownloadUrl = "https://www.viber.com/download/"

    /// `+95 9 787 844 882` → `+959787844882`.
    nonisolated static func toDialable(_ number: String) -> String {
        number.replacingOccurrences(of: #"[^\d+]"#, with: "", options: .regularExpression)
    }

    /// Opens the dialler with `number` pre-filled (`tel:` only pre-fills).
    static func dial(_ number: String) async {
        let launched = await open(URL(string: "tel:\(toDialable(number))"))
        if !launched { SnackBarCenter.shared.show(number) }
    }

    /// Opens the user's email app with `address` filled in.
    static func email(_ address: String) async {
        let launched = await open(URL(string: "mailto:\(address)"))
        if !launched { SnackBarCenter.shared.show(address) }
    }

    /// Viber's direct-chat URI for `number`. The application receives a
    /// compact E.164 value while the number shown in the UI remains readable.
    nonisolated static func viberChatUri(_ number: String) -> URL? {
        // Dart's `Uri(queryParameters:)` percent-encodes the leading `+`
        // (`%2B`); URLComponents would leave it, and Viber reads it as a space.
        let encoded = toDialable(number).addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        return URL(string: "viber://chat?number=\(encoded)")
    }

    /// Messenger's universal page link opens the Messenger app when
    /// installed, otherwise it remains a usable web destination.
    nonisolated static func messengerUri(_ page: String) -> URL? {
        URL(string: "https://m.me/\(page)")
    }

    /// Opens a support chat in Viber, or Viber's download page.
    static func viber(_ number: String) async {
        await launchWithFallback(
            primary: viberChatUri(number),
            fallback: URL(string: viberDownloadUrl),
            unavailableMessage: number
        )
    }

    /// Opens the business page in Messenger or its browser fallback.
    static func messenger(_ page: String) async {
        await launchWithFallback(
            primary: messengerUri(page),
            fallback: URL(string: "https://www.messenger.com/"),
            unavailableMessage: "m.me/\(page)"
        )
    }

    /// Opens any external URL (Dart `launchUrl(uri, mode: externalApplication)`).
    @discardableResult
    static func open(_ url: URL?) async -> Bool {
        guard let url else { return false }
        return await UIApplication.shared.open(url)
    }

    private static func launchWithFallback(primary: URL?, fallback: URL?, unavailableMessage: String) async {
        var launched = await open(primary)
        if !launched { launched = await open(fallback) }
        if !launched { SnackBarCenter.shared.show(unavailableMessage) }
    }
}
