// Port of lib/features/ticket/di/ticket_module.dart
import Foundation

/// Wiring for the ticket feature: service → repository → notifier.
extension AppContainer {
    /// `ticketMockServiceProvider`.
    var ticketMockService: TicketMockService {
        provide { TicketMockService() }
    }

    /// `ticketRepositoryProvider`.
    var ticketRepository: TicketRepository {
        provide { TicketRepositoryImpl(ticketMockService) as TicketRepository }
    }

    // ---- Use cases ----------------------------------------------------------

    /// `getMyTicketsUseCaseProvider`.
    var getMyTicketsUseCase: GetMyTicketsUseCase {
        provide { GetMyTicketsUseCase(ticketRepository) }
    }
}
