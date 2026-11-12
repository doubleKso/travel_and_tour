// Port of lib/features/hotel/data/repositories/hotel_repository_impl.dart
import Foundation

/// Dart's `HotelAuthenticatedRequestRunner`:
/// `Future<T> Function<T>(Future<T> Function(String accessToken) request)`.
///
/// Swift closures cannot be generic, so the runner is a protocol with one
/// generic call; `runAuthenticated { token in … }` reads like the Dart call.
/// DI hands in `AuthNotifier.withValidAccessToken` (see `HotelModule`).
protocol HotelAuthenticatedRequestRunner {
    func callAsFunction<T>(_ request: @escaping (String) async throws -> T) async throws -> T
}

final class HotelRepositoryImpl: HotelRepository {
    private let remote: HotelRemoteService
    private let runAuthenticated: HotelAuthenticatedRequestRunner

    init(_ remote: HotelRemoteService, _ runAuthenticated: HotelAuthenticatedRequestRunner) {
        self.remote = remote
        self.runAuthenticated = runAuthenticated
    }

    func getHotels() async -> AppResult<[HotelModel]> {
        let remote = self.remote
        let runAuthenticated = self.runAuthenticated
        return await `guard` {
            .success(
                try await runAuthenticated { token in
                    try await remote.getActiveHotels(
                        accessToken: token.isEmpty ? nil : token
                    )
                }
            )
        }
    }

    func getCategories() async -> AppResult<[HotelCategory]> {
        // The public catalogue now lists concrete hotels, not stay categories.
        return .success([])
    }

    private func `guard`<T>(_ body: () async throws -> AppResult<T>) async -> AppResult<T> {
        do {
            return try await body()
        } catch {
            return .failure(FailureMapper.from(error))
        }
    }
}
