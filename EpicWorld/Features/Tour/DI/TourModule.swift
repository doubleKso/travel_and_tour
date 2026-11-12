// Port of lib/features/tour/di/tour_module.dart

import Foundation

extension AppContainer {
    /// `tourRemoteServiceProvider`.
    var tourRemoteService: TourRemoteService {
        provide { TourRemoteService(functions) }
    }

    /// `tourRepositoryProvider`.
    var tourRepository: TourRepository {
        provide {
            TourRepositoryImpl(
                tourRemoteService,
                AuthNotifierTourRequestRunner(notifier: authNotifier)
            ) as TourRepository
        }
    }

    // ---- Use cases ------------------------------------------------------------

    /// `getTourPackagesUseCaseProvider`.
    var getTourPackagesUseCase: GetTourPackagesUseCase {
        provide { GetTourPackagesUseCase(tourRepository) }
    }
}

/// `ref.watch(authNotifierProvider.notifier).withValidAccessToken` — the Dart
/// module hands the repository that generic method's tear-off.
private struct AuthNotifierTourRequestRunner: TourAuthenticatedRequestRunner {
    let notifier: AuthNotifier

    func callAsFunction<T>(_ request: @escaping (_ accessToken: String) async throws -> T) async throws -> T {
        try await notifier.withValidAccessToken { token in
            try await request(token)
        }
    }
}
