// Port of lib/features/notification/data/datasources/notification_remote_service.dart

import Foundation

/// Calls the shared `dcExec` Firebase HTTPS callable.
final class NotificationRemoteService {
    private let functions: CallableInvoking

    init(_ functions: CallableInvoking) {
        self.functions = functions
    }

    func getMyNotifications(accessToken: String, userId: String, role: String) async throws -> [AppNotification] {
        let payload = try await execute(
            operation: "GetMyNotifications",
            accessToken: accessToken,
            variables: ["userId": userId, "role": role]
        )
        guard let notifications = Dart.list(payload["notifications"]) else { return [] }
        return Dart.maps(notifications).map(AppNotification.fromApiJson)
    }

    func getMyNotificationReads(accessToken: String) async throws -> Set<String> {
        let payload = try await execute(
            operation: "GetMyNotificationReads",
            accessToken: accessToken
        )
        guard let reads = Dart.list(payload["notificationReads"]) else { return [] }
        return Set(
            Dart.maps(reads)
                .map { item in Dart.str(item["notificationId"]) ?? "" }
                .filter { id in !id.isEmpty }
        )
    }

    /// Persists that the authenticated member has opened `notificationId`.
    ///
    /// `InsertNotificationRead` derives `userId` from the access token, so the
    /// client deliberately sends only the notification being opened.
    func insertNotificationRead(accessToken: String, notificationId: String) async throws {
        let payload = try await execute(
            operation: "InsertNotificationRead",
            accessToken: accessToken,
            variables: ["notificationId": notificationId]
        )
        let insertedId = Dart.str(payload["notificationRead_insert"]) ?? ""
        if insertedId.isEmpty {
            throw FormatException(
                "InsertNotificationRead did not confirm the insert. "
                    + "Response fields: \(payload.keys.joined(separator: ", "))"
            )
        }
    }

    /// Updates the authenticated member's two-factor setting through dcExec.
    ///
    /// The published callable contract specifies `twoFactorEnabled` as a string,
    /// so the lowercase string goes first. Deployments whose schema declares a
    /// real Boolean reject that, and the setting would silently never change —
    /// so a rejected string is retried once as a Boolean, and the log says which
    /// spelling the server accepted.
    func setMyTwoFactor(accessToken: String, userId: String, twoFactorEnabled: Bool) async throws {
        do {
            try await writeTwoFactor(
                accessToken: accessToken,
                userId: userId,
                value: twoFactorEnabled ? "true" : "false"
            )
            return
        } catch {
            Self.log("SetMyTwoFactor", "retry", [
                "reason": "\(error)",
                "resendingAs": "bool",
            ])
        }
        try await writeTwoFactor(
            accessToken: accessToken,
            userId: userId,
            value: twoFactorEnabled
        )
    }

    private func writeTwoFactor(accessToken: String, userId: String, value: Any) async throws {
        let payload = try await execute(
            operation: "SetMyTwoFactor",
            accessToken: accessToken,
            variables: ["id": userId, "twoFactorEnabled": value]
        )
        // Deployments have answered with either the mutation alias or a plain
        // ok/appUser body; anything else means the write did not land, and the
        // keys are named so the failure is diagnosable from the log alone.
        let accepted = payload.keys.contains("appUser_update")
            || payload.keys.contains("appUser")
            || Dart.bool(payload["ok"]) == true
        if !accepted {
            throw FormatException(
                "SetMyTwoFactor did not confirm the update. "
                    + "Response fields: \(payload.keys.joined(separator: ", "))"
            )
        }
    }

    private func execute(operation: String, accessToken: String, variables: JSON = [:]) async throws -> JSON {
        let url = F.functionsUrl(Endpoints.dcExec)
        let name = "\(Endpoints.dcExec):\(operation)"
        let body: JSON = [
            "operation": operation,
            // dcExec expects an object, not a JSON-encoded string.
            "variables": variables,
            "accessToken": accessToken,
        ]
        Self.log(name, "request", ["url": url, "data": Self.redact(body) as Any])
        do {
            let result = try await functions.call(url, body)
            Self.log(name, "response", Self.redact(result))
            return try ApiException.callablePayload(result, endpoint: name)
        } catch {
            Self.log(name, "error", ["message": "\(error)"])
            throw error
        }
    }

    private static func log(_ endpoint: String, _ direction: String, _ value: Any?) {
        #if DEBUG
        let output: String
        if let value = Dart.unwrap(value),
           JSONSerialization.isValidJSONObject(value),
           let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted]),
           let text = String(data: data, encoding: .utf8) {
            output = text
        } else {
            output = Dart.interpolate(value)
        }
        superPrint(output, title: "Notification \(endpoint) \(direction)", isApi: true)
        #endif
    }

    private static func redact(_ value: Any?) -> Any? {
        guard let value = Dart.unwrap(value) else { return nil }
        if let map = Dart.map(value) {
            var out: JSON = [:]
            for (key, element) in map {
                out[key] = key.lowercased() == "accesstoken"
                    ? mask(Dart.str(element))
                    : (redact(element) ?? NSNull())
            }
            return out
        }
        if let list = Dart.list(value) {
            return list.map { redact($0) ?? NSNull() }
        }
        return value
    }

    private static func mask(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "<empty>" }
        if value.count <= 4 { return "****" }
        return "\(value.prefix(2))…\(value.suffix(2))"
    }
}
