// Port of lib/features/booking/data/datasources/guest_booking_store.dart

import Foundation

/// Guest bookings remembered on this device, in encrypted storage.
///
/// The reference/email pair is all it takes to open someone's reservation, so
/// it is kept where the platform protects it — Keychain, EncryptedSharedPrefs,
/// WebCrypto-backed storage on web — rather than in plain preferences beside
/// the app's other settings.
///
/// Every read is defensive: storage can be unavailable (a locked keystore, a
/// browser blocking site data) and the payload can be a leftover from an older
/// build. Neither is worth failing a screen for, so both come back as "no
/// bookings on this device".
enum GuestBookingStore {
    private static let key = "booking.guest_bookings"

    /// Enough to cover a family's worth of trips without letting a shared device
    /// accumulate an unbounded list of other people's references.
    private static let maxRecords = 10

    /// `flutter_secure_storage` with its default iOS layout (same service and
    /// account), so the native build reads what the Flutter build stored.
    /// Swappable for tests, like `SecureSessionStore.keychain`.
    static var storage = KeychainStore()

    /// Newest first. Records without a reference or email are dropped: they
    /// cannot be looked up, so they can only ever draw a dead row.
    static func read() async -> [GuestBookingRecord] {
        let value = storage.read(key)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if value.isEmpty { return [] }
        guard let decoded = try? jsonDecode(value), Dart.isList(decoded) else { return [] }
        return Dart.maps(decoded)
            .map { GuestBookingRecord.fromJson($0) }
            .filter { !$0.reference.isEmpty && !$0.email.isEmpty }
    }

    /// Adds a booking, or refreshes the one already stored under the same
    /// reference.
    ///
    /// A booking already on the list keeps its place — a lookup that refreshes
    /// one card must not shuffle the cards around it. New ones go to the front,
    /// and the oldest fall off the end.
    static func save(_ record: GuestBookingRecord) async {
        if record.reference.isEmpty || record.email.isEmpty { return }
        let existing = await read()
        let known = existing.contains { sameBooking($0, record) }
        await write(
            known
                ? existing.map { sameBooking($0, record) ? record : $0 }
                : [record] + existing
        )
    }

    /// Applies a server refresh in one write, keeping the stored order.
    ///
    /// Records the refresh did not cover — a booking the server no longer
    /// returns, say — are left exactly as they were rather than dropped, so a
    /// half-answered refresh cannot erase what the device knows.
    static func replaceAll(_ records: [GuestBookingRecord]) async {
        await write(records)
    }

    static func updateStatus(_ reference: String, _ status: String) async {
        let trimmed = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return }
        let existing = await read()
        var changed = false
        let updated = existing.map { record -> GuestBookingRecord in
            if record.reference != trimmed || record.status == status {
                return record
            }
            changed = true
            return record.copyWith(status: status)
        }
        if changed { await write(updated) }
    }

    static func remove(_ reference: String) async {
        let existing = await read()
        let trimmed = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        let remaining = existing.filter { $0.reference != trimmed }
        if remaining.count == existing.count { return }
        await write(remaining)
    }

    static func clear() async {
        // A failed delete leaves nothing to do: the list is already unreadable,
        // which is what clearing it was for.
        storage.delete(key)
    }

    private static func sameBooking(_ a: GuestBookingRecord, _ b: GuestBookingRecord) -> Bool {
        a.reference == b.reference
    }

    private static func write(_ records: [GuestBookingRecord]) async {
        let capped = Array(records.prefix(maxRecords))
        // Storage being unwritable costs the customer the shortcut back to the
        // booking, not the booking itself — the confirmation email still has the
        // reference. Not worth interrupting the flow for.
        storage.write(key, jsonEncode(capped.map { $0.toJson() }))
    }
}
