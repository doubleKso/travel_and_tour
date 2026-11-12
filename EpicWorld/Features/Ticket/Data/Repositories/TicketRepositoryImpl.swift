// Port of lib/features/ticket/data/repositories/ticket_repository_impl.dart
import Foundation

final class TicketRepositoryImpl: TicketRepository {
    private let mock: TicketMockService

    init(_ mock: TicketMockService) {
        self.mock = mock
    }

    func fetchMyTickets() async -> AppResult<[TicketModel]> {
        do {
            // Pending API (Dart's own note): GET Endpoints.myTickets via
            // TicketRemoteService, map the DTOs with toDomain() and return them
            // here.
            try await Task.sleep(for: Duration(milliseconds: 400))
            return .success(mock.getTickets(DateTime.now()))
        } catch let error as HTTPException {
            return .failure(FailureMapper.from(error))
        } catch {
            return .failure(.unexpected("\(error)"))
        }
    }
}
