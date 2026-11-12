// Port of lib/features/tour/data/repositories/tour_repository_impl.dart

import Foundation

/// Dart's `TourAuthenticatedRequestRunner` typedef —
/// `Future<T> Function<T>(Future<T> Function(String accessToken) request)`.
///
/// Swift closures cannot be generic, so the runner is a protocol with one
/// generic call; `TourModule` adapts `AuthNotifier.withValidAccessToken` to it
/// (Dart passes that method's tear-off).
protocol TourAuthenticatedRequestRunner {
    func callAsFunction<T>(_ request: @escaping (_ accessToken: String) async throws -> T) async throws -> T
}

final class TourRepositoryImpl: TourRepository {
    private let remote: TourRemoteService
    private let runAuthenticated: TourAuthenticatedRequestRunner

    init(_ remote: TourRemoteService, _ runAuthenticated: TourAuthenticatedRequestRunner) {
        self.remote = remote
        self.runAuthenticated = runAuthenticated
    }

    func getPackages() async -> AppResult<[TourPackage]> {
        let remote = self.remote
        do {
            let packages = try await runAuthenticated { token in
                try await remote.getActiveTourPackages(
                    accessToken: token.isEmpty ? nil : token
                )
            }
            return .success(packages)
        } catch {
            return .failure(FailureMapper.from(error))
        }
    }
}
