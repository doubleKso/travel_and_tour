import Foundation

/// Reads the expiry out of a backend access token without verifying it — the
/// port of lib/core/utils/access_token.dart.
///
/// The server stays the only authority on whether a token is valid — the app
/// only needs to know *when to stop using one*, so an authenticated call can
/// renew the session before it fails instead of surfacing "Access token
/// expired" to the customer.
enum AccessToken {
    /// How close to `exp` a token may get before it counts as spent. Covers
    /// clock skew plus the round trip of the call it is about to sign.
    static let refreshLeeway = Duration(minutes: 2)

    /// The `exp` claim of a JWT access token, or nil when `token` is empty,
    /// opaque, or otherwise unreadable by the client.
    static func expiryOf(_ token: String) -> DateTime? {
        let parts = token.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        var base64 = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder == 1 { return nil }
        if remainder > 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        guard let data = Data(base64Encoded: base64),
              let text = String(data: data, encoding: .utf8),
              let payload = try? jsonDecode(text),
              let map = Dart.map(payload) else { return nil }
        let exp = map["exp"]
        let seconds = Dart.isNum(exp) ? Dart.int(exp) : Dart.parseInt(Dart.interpolate(exp))
        guard let seconds, seconds > 0 else { return nil }
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true)
    }

    /// True when `token` should be renewed before the next authenticated
    /// call: it is empty, past `exp`, within `leeway` of it, or unreadable.
    ///
    /// Unreadable counts as stale on purpose. Refreshing one extra time costs
    /// a round trip; sending a dead token costs the customer their payment.
    static func needsRefresh(_ token: String, leeway: Duration = refreshLeeway, now: DateTime? = nil) -> Bool {
        if token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        guard let expiry = expiryOf(token) else { return true }
        return !expiry.isAfter((now ?? DateTime.now()).toUtc().add(leeway))
    }
}
