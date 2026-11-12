// Port of lib/features/ticket/domain/repositories/ticket_repository.dart
import Foundation

/// Read side of the ticket wallet.
protocol TicketRepository: AnyObject {
    /// Every ticket belonging to the signed-in user.
    func fetchMyTickets() async -> AppResult<[TicketModel]>
}
