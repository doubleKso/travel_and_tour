// Port of lib/features/ticket/domain/usecases/get_my_tickets_use_case.dart
import Foundation

/// The signed-in user's tickets.
final class GetMyTicketsUseCase: UseCase {
    private let repository: TicketRepository

    init(_ repository: TicketRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: NoParams) async -> AppResult<[TicketModel]> {
        await repository.fetchMyTickets()
    }
}
