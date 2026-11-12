// Port of lib/features/notification/data/models/push_message.dart

import Foundation

/// Only the identifiers needed to open the inbox are stored in a local alert.
/// Remote payloads never select arbitrary routes or supply trusted booking data.
///
/// A `final class` rather than a struct: the app compares pending taps by
/// identity (`===`, Dart's `identical`), see `AppWidget`.
final class PushMessage {
    let messageId: String?
    let notificationId: String?
    let title: String?
    let body: String?

    init(
        messageId: String? = nil,
        notificationId: String? = nil,
        title: String? = nil,
        body: String? = nil
    ) {
        self.messageId = messageId
        self.notificationId = notificationId
        self.title = title
        self.body = body
    }

    static func fromRemoteMessage(_ message: RemoteMessage) -> PushMessage {
        PushMessage(
            messageId: text(message.messageId),
            notificationId: text(message.data["notificationId"]),
            title: text(message.notification?.title) ?? text(message.data["title"]),
            body: text(message.notification?.body) ?? text(message.data["body"])
        )
    }

    var hasContent: Bool { title != nil || body != nil }

    /// FCM ids distinguish deliveries even when the same inbox item is updated.
    var deliveryId: String? { messageId ?? notificationId }

    var localId: Int {
        guard let key = deliveryId else {
            let micros = Int((Date().timeIntervalSince1970 * 1_000_000).rounded(.down))
            return micros & 0x7fffffff
        }
        // A deterministic positive Android id also works across isolates/restarts.
        var hash = 0
        for unit in key.utf16 {
            hash = (hash * 31 + Int(unit)) & 0x7fffffff
        }
        return hash
    }

    func toPayload() -> String {
        // Dart's `jsonEncode` keeps insertion order; sorted keys give the same
        // `messageId`, `notificationId` order here.
        let object: [String: Any] = [
            "messageId": messageId ?? NSNull(),
            "notificationId": notificationId ?? NSNull(),
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    static func fromPayload(_ payload: String?) -> PushMessage? {
        guard let payload, !payload.isEmpty else { return nil }
        do {
            let decoded = try jsonDecode(payload)
            guard let map = decoded as? [String: Any] else { return nil }
            return PushMessage(
                messageId: text(map["messageId"]),
                notificationId: text(map["notificationId"])
            )
        } catch {
            // Dart: `on FormatException` — `jsonDecode` throws nothing else.
            return nil
        }
    }

    private static func text(_ value: Any?) -> String? {
        guard let string = Dart.unwrap(value) as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - firebase_messaging's RemoteMessage

/// The Swift side of firebase_messaging's `RemoteMessage`: the parts of an FCM
/// delivery this app reads.
///
/// Built from an APNs `userInfo` dictionary exactly the way FlutterFire's iOS
/// plugin does (`remoteMessageUserInfoToDict`), so `PushMessage` sees the same
/// fields the Dart code saw.
struct RemoteMessage {
    var messageId: String?
    var data: JSON
    var notification: RemoteNotification?

    init(messageId: String? = nil, data: JSON = [:], notification: RemoteNotification? = nil) {
        self.messageId = messageId
        self.data = data
        self.notification = notification
    }

    /// FlutterFire's `remoteMessageUserInfoToDict`.
    static func fromUserInfo(_ userInfo: [AnyHashable: Any]) -> RemoteMessage {
        var messageId: String?
        var data: JSON = [:]
        for (rawKey, value) in userInfo {
            let key = Dart.describe(rawKey.base)
            // message.messageId
            if key == "gcm.message_id" || key == "google.message_id" || key == "message_id" {
                messageId = Dart.str(value)
                continue
            }
            // message.messageType / collapseKey / from / sentTime / to are not
            // read by this app; they are still kept out of `data`, as FlutterFire does.
            if ["message_type", "collapse_key", "from", "google.c.a.ts", "to", "google.to"].contains(key) {
                continue
            }
            // Keys that never belong in data.
            if key == "aps" || key.hasPrefix("gcm.") || key.hasPrefix("google.") {
                continue
            }
            // message.apple.imageUrl
            if key == "fcm_options" {
                continue
            }
            data[key] = value
        }

        var notification: RemoteNotification?
        if let aps = Dart.map(userInfo["aps"]), let alert = Dart.unwrap(aps["alert"]) {
            // `alert` can be a string or a dictionary.
            if let title = alert as? String {
                notification = RemoteNotification(title: title, body: nil)
            } else if let alertDict = Dart.map(alert) {
                notification = RemoteNotification(
                    title: Dart.str(alertDict["title"]),
                    body: Dart.str(alertDict["body"])
                )
            } else {
                notification = RemoteNotification(title: nil, body: nil)
            }
        }
        return RemoteMessage(messageId: messageId, data: data, notification: notification)
    }
}

/// firebase_messaging's `RemoteNotification` (title/body only).
struct RemoteNotification {
    var title: String?
    var body: String?

    init(title: String? = nil, body: String? = nil) {
        self.title = title
        self.body = body
    }
}
