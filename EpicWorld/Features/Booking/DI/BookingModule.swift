// Port of lib/features/booking/di/booking_module.dart

import Foundation

/// Dependency graph for booking: data sources → repositories. UI state lives
/// in `Presentation/Providers/BookingProviders.swift`.
extension AppContainer {
    /// `bookingMockServiceProvider`.
    var bookingMockService: BookingMockService {
        provide { BookingMockService() }
    }

    /// `flightCatalogueRemoteServiceProvider`.
    var flightCatalogueRemoteService: FlightCatalogueRemoteService {
        provide { FlightCatalogueRemoteService(functions) }
    }

    /// `flightSearchCallableServiceProvider`.
    var flightSearchCallableService: FlightSearchCallableService {
        provide { FlightSearchCallableService(functions) }
    }

    /// `flightHoldCallableServiceProvider`.
    var flightHoldCallableService: FlightHoldCallableService {
        provide { FlightHoldCallableService(functions) }
    }

    /// `confirmTicketingCallableServiceProvider`.
    var confirmTicketingCallableService: ConfirmTicketingCallableService {
        provide { ConfirmTicketingCallableService(functions) }
    }

    /// `smartPayCallableServiceProvider`.
    var smartPayCallableService: SmartPayCallableService {
        provide { SmartPayCallableService(functions) }
    }

    /// `promoCodeCallableServiceProvider`.
    var promoCodeCallableService: PromoCodeCallableService {
        provide { PromoCodeCallableService(functions) }
    }

    /// `nrcRemoteServiceProvider`.
    var nrcRemoteService: NrcRemoteService {
        provide { NrcRemoteService(functions) }
    }

    /// `serviceEnquiryCallableServiceProvider`.
    var serviceEnquiryCallableService: ServiceEnquiryCallableService {
        provide { ServiceEnquiryCallableService(functions) }
    }

    /// `bookingRepositoryProvider`. The session runner is
    /// `ref.watch(authNotifierProvider.notifier).withValidAccessToken`.
    var bookingRepository: BookingRepository {
        provide {
            BookingRepositoryImpl(
                bookingMockService,
                flightCatalogueRemoteService,
                flightSearchCallableService,
                flightHoldCallableService,
                serviceEnquiryCallableService,
                AuthenticatedRequestRunner { @MainActor [unowned self] request in
                    try await self.authNotifier.withValidAccessToken { token in
                        try await request(token)
                    }
                }
            ) as BookingRepository
        }
    }

    /// `guestBookingCallableServiceProvider`.
    var guestBookingCallableService: GuestBookingCallableService {
        provide { GuestBookingCallableService(functions) }
    }

    /// `guestBookingRepositoryProvider`.
    var guestBookingRepository: GuestBookingRepository {
        provide { GuestBookingRepositoryImpl(guestBookingCallableService) as GuestBookingRepository }
    }

    // ---- Use cases --------------------------------------------------------

    /// `createServiceEnquiryUseCaseProvider`.
    var createServiceEnquiryUseCase: CreateServiceEnquiryUseCase {
        provide { CreateServiceEnquiryUseCase(bookingRepository) }
    }

    /// `getDailyMinPricesUseCaseProvider`.
    var getDailyMinPricesUseCase: GetDailyMinPricesUseCase {
        provide { GetDailyMinPricesUseCase(bookingRepository) }
    }

    /// `getMyServiceEnquiriesUseCaseProvider`.
    var getMyServiceEnquiriesUseCase: GetMyServiceEnquiriesUseCase {
        provide { GetMyServiceEnquiriesUseCase(bookingRepository) }
    }

    /// `holdFlightUseCaseProvider`.
    var holdFlightUseCase: HoldFlightUseCase {
        provide { HoldFlightUseCase(bookingRepository) }
    }

    /// `loadGuestBookingCheckoutUseCaseProvider`.
    var loadGuestBookingCheckoutUseCase: LoadGuestBookingCheckoutUseCase {
        provide { LoadGuestBookingCheckoutUseCase(guestBookingRepository) }
    }

    /// `searchTripsUseCaseProvider`.
    var searchTripsUseCase: SearchTripsUseCase {
        provide { SearchTripsUseCase(bookingRepository) }
    }

    /// `submitFlightSearchUseCaseProvider`.
    var submitFlightSearchUseCase: SubmitFlightSearchUseCase {
        provide { SubmitFlightSearchUseCase(bookingRepository) }
    }
}
