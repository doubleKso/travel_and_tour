// Port of lib/features/hotel/di/hotel_module.dart
import Foundation

/// `ref.watch(authNotifierProvider.notifier).withValidAccessToken` as the
/// repository's `HotelAuthenticatedRequestRunner`.
private struct AuthNotifierHotelRequestRunner: HotelAuthenticatedRequestRunner {
    let authNotifier: AuthNotifier

    func callAsFunction<T>(_ request: @escaping (String) async throws -> T) async throws -> T {
        try await authNotifier.withValidAccessToken { accessToken in
            try await request(accessToken)
        }
    }
}

extension AppContainer {
    /// `hotelRemoteServiceProvider`.
    var hotelRemoteService: HotelRemoteService {
        provide { HotelRemoteService(functions) }
    }

    /// `hotelRepositoryProvider`.
    var hotelRepository: HotelRepository {
        provide {
            HotelRepositoryImpl(
                hotelRemoteService,
                AuthNotifierHotelRequestRunner(authNotifier: authNotifier)
            ) as HotelRepository
        }
    }

    // ---- Use cases ------------------------------------------------------------

    /// `getHotelCategoriesUseCaseProvider`.
    var getHotelCategoriesUseCase: GetHotelCategoriesUseCase {
        provide { GetHotelCategoriesUseCase(hotelRepository) }
    }

    /// `getHotelsUseCaseProvider`.
    var getHotelsUseCase: GetHotelsUseCase {
        provide { GetHotelsUseCase(hotelRepository) }
    }
}
