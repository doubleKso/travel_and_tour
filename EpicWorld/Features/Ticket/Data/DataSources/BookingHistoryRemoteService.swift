// Port of lib/features/ticket/data/datasources/booking_history_remote_service.dart
import Foundation

/// Customer booking history backed by the public `dcExec` callable.
final class BookingHistoryRemoteService {
    private let functions: CallableInvoking

    init(_ functions: CallableInvoking) {
        self.functions = functions
    }

    func getMyBookings(
        userId: String,
        email: String,
        accessToken: String?
    ) async throws -> [BookingHistoryItem] {
        let body = try await execute(
            operation: "GetMyBookings",
            accessToken: accessToken,
            variables: ["userId": userId, "email": email]
        )
        return Self.list(body["bookings"]).map(BookingHistoryItem.fromJson)
    }

    /// One booking looked up by its `EW-` reference.
    ///
    /// Used to resume payment from history: the record here is the server's
    /// current truth for the amount and status, so the payment screen is rebuilt
    /// from it rather than from the possibly stale list row that was tapped.
    /// Returns nil when the reference matches nothing for this customer.
    func getMyBookingByRef(
        reference: String,
        userId: String,
        email: String,
        accessToken: String?
    ) async throws -> BookingHistoryItem? {
        let body = try await execute(
            operation: "GetMyBookingByRef",
            accessToken: accessToken,
            variables: ["reference": reference, "userId": userId, "email": email]
        )
        let bookings = Self.list(body["bookings"])
        guard let first = bookings.first else { return nil }
        return BookingHistoryItem.fromJson(first)
    }

    func getMyBookingSegments(
        bookingId: String,
        accessToken: String?
    ) async throws -> [BookingHistorySegment] {
        let body = try await execute(
            operation: "GetMyBookingSegments",
            accessToken: accessToken,
            variables: ["bookingId": bookingId]
        )
        return Self.list(body["bookingSegments"]).map(BookingHistorySegment.fromJson)
    }

    func getMyBookingPassengers(
        bookingId: String,
        accessToken: String?
    ) async throws -> [BookingHistoryPassenger] {
        let body = try await execute(
            operation: "GetMyBookingPassengers",
            accessToken: accessToken,
            variables: ["bookingId": bookingId]
        )
        return Self.list(body["passengers"]).map(BookingHistoryPassenger.fromJson)
    }

    private func execute(
        operation: String,
        accessToken: String?,
        variables: JSON
    ) async throws -> JSON {
        // A null token travels as JSON null, as the Dart map did.
        let token: Any = accessToken.map { $0 as Any } ?? NSNull()
        let result = try await functions.call(
            F.functionsUrl(Endpoints.dcExec),
            [
                "accessToken": token,
                "operation": operation,
                "variables": variables,
            ] as JSON
        )
        return try ApiException.callablePayload(
            result,
            endpoint: "\(Endpoints.dcExec)/\(operation)"
        )
    }

    private static func list(_ value: Any?) -> [JSON] { Dart.maps(value) }
}
