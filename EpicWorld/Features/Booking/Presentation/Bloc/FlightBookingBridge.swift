// Port of lib/features/booking/presentation/bloc/flight_booking_bridge.dart
//
// The one place the container and the bloc meet.
//
// In Flutter, Riverpod built the bloc (`flightBookingBlocProvider`), handed it
// to the widget tree (`FlightBookingBlocScope` → `BlocProvider.value`) and
// mirrored its state back into Riverpod (`flightBookingStateProvider`). Here
// the container builds it and views reach it directly, so only the first
// piece remains (PORTING_GUIDE §5):
//
//   flightBookingBlocProvider          → container.flightBookingBloc
//   flightBookingStateProvider         → container.flightBookingBloc.state
//   context.read<FlightBookingBloc>()  → container.flightBookingBloc
//   FlightBookingBlocScope             → (not needed: every view reads the container)

import Foundation

extension AppContainer {
    /// `flightBookingBlocProvider` — the app-wide `FlightBookingBloc`, built
    /// from the booking use cases. Overriding `bookingRepository` in a test
    /// reaches the bloc through the use cases, exactly as before.
    var flightBookingBloc: FlightBookingBloc {
        provide {
            FlightBookingBloc(
                submitFlightSearch: submitFlightSearchUseCase,
                searchTrips: searchTripsUseCase,
                getDailyMinPrices: getDailyMinPricesUseCase
            )
        }
    }
}
