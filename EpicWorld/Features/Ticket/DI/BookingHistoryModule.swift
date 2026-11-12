// Port of lib/features/ticket/di/booking_history_module.dart
import Foundation

extension AppContainer {
    /// `bookingHistoryRemoteServiceProvider`.
    var bookingHistoryRemoteService: BookingHistoryRemoteService {
        provide { BookingHistoryRemoteService(functions) }
    }
}
