import Foundation

/// One business operation — the Swift side of `app_core`'s `UseCase<T, Params>`.
/// Presentation code calls use cases; use cases call repository protocols.
/// Call it like a function, exactly as in Dart: `await login(params)`.
///
/// `Params` is whatever the operation needs — a tuple such as
/// `(email: String, code: String)` (Dart record `({String email, String code})`),
/// a single value, or `NoParams`.
///
/// ```swift
/// final class GetMyTicketsUseCase: UseCase {
///     private let repository: TicketRepository
///     init(_ repository: TicketRepository) { self.repository = repository }
///     func callAsFunction(_ params: NoParams) async -> AppResult<[TicketModel]> {
///         await repository.getMyTickets()
///     }
/// }
/// ```
protocol UseCase {
    associatedtype Output
    associatedtype Params
    func callAsFunction(_ params: Params) async -> AppResult<Output>
}

/// A use case that completes synchronously.
protocol SyncUseCase {
    associatedtype Output
    associatedtype Params
    func callAsFunction(_ params: Params) -> AppResult<Output>
}

/// A use case that emits over time (Dart `Stream<T>`).
protocol StreamUseCase {
    associatedtype Output
    associatedtype Params
    func callAsFunction(_ params: Params) -> AsyncStream<Output>
}

/// Marker for use cases that take no input.
struct NoParams: Equatable {
    init() {}
}
