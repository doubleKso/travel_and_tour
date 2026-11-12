// Port of lib/features/ticket/presentation/providers/ticket_notifier.dart
import Foundation
import Observation

/// The user's tickets, split into active vs. past for the Tickets and History
/// tabs.
struct TicketState {
    let tickets: [TicketModel]
    let isLoading: Bool

    /// True once a fetch has completed — lets a page tell "empty" from
    /// "not fetched yet".
    let loaded: Bool
    let error: String?

    init(
        tickets: [TicketModel] = [],
        isLoading: Bool = false,
        loaded: Bool = false,
        error: String? = nil
    ) {
        self.tickets = tickets
        self.isLoading = isLoading
        self.loaded = loaded
        self.error = error
    }

    /// Every ticket the user has, newest trip first.
    var all: [TicketModel] {
        tickets.sorted { $1.tripDate.compareTo($0.tripDate) < 0 }
    }

    /// Upcoming trips, soonest first.
    func active(_ now: DateTime) -> [TicketModel] {
        tickets.filter { $0.isActive(now) }
            .sorted { $0.tripDate.compareTo($1.tripDate) < 0 }
    }

    /// Past trips, most recent first.
    func history(_ now: DateTime) -> [TicketModel] {
        tickets.filter { !$0.isActive(now) }
            .sorted { $1.tripDate.compareTo($0.tripDate) < 0 }
    }

    func copyWith(
        tickets: [TicketModel]? = nil,
        isLoading: Bool? = nil,
        loaded: Bool? = nil,
        error: String? = nil,
        clearError: Bool = false
    ) -> TicketState {
        TicketState(
            tickets: tickets ?? self.tickets,
            isLoading: isLoading ?? self.isLoading,
            loaded: loaded ?? self.loaded,
            error: clearError ? nil : (error ?? self.error)
        )
    }
}

@MainActor
@Observable
final class TicketNotifier {
    private(set) var state: TicketState
    private let getMyTickets: GetMyTicketsUseCase

    init(getMyTickets: GetMyTicketsUseCase) {
        self.getMyTickets = getMyTickets
        state = TicketState()
    }

    func load() async {
        state = state.copyWith(isLoading: true, clearError: true)
        let result = await getMyTickets(NoParams())
        result.fold(
            { failure in
                state = state.copyWith(
                    isLoading: false,
                    loaded: true,
                    error: failure.message
                )
            },
            { tickets in
                state = state.copyWith(
                    tickets: tickets,
                    isLoading: false,
                    loaded: true,
                    clearError: true
                )
            }
        )
    }

    /// Adds a ticket the user just booked, so the wallet updates without a
    /// round-trip to the server.
    func addTicket(_ ticket: TicketModel) {
        state = state.copyWith(tickets: state.tickets + [ticket])
    }
}
