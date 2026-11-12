// Port of lib/features/ticket/presentation/providers/ticket_providers.dart
import Foundation

extension AppContainer {
    /// `ticketNotifierProvider`.
    var ticketNotifier: TicketNotifier {
        provide { TicketNotifier(getMyTickets: getMyTicketsUseCase) }
    }
}
