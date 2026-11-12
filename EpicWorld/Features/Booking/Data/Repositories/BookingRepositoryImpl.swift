// Port of lib/features/booking/data/repositories/booking_repository_impl.dart

import Foundation

/// Dart:
/// `typedef AuthenticatedRequestRunner = Future<T> Function<T>(Future<T> Function(String accessToken) request);`
///
/// Swift closures cannot be generic, so the runner wraps a type-erased closure
/// and is called exactly like the Dart function: `try await runAuthenticated { token in … }`.
/// `booking_module` builds it from `authNotifier.withValidAccessToken`.
struct AuthenticatedRequestRunner {
    private let run: (@escaping (String) async throws -> Any) async throws -> Any

    init(_ run: @escaping (@escaping (String) async throws -> Any) async throws -> Any) {
        self.run = run
    }

    func callAsFunction<T>(_ request: @escaping (String) async throws -> T) async throws -> T {
        let value = try await run { token in try await request(token) }
        guard let typed = value as? T else {
            throw StateError("AuthenticatedRequestRunner returned \(type(of: value)) instead of \(T.self)")
        }
        return typed
    }
}

/// Combines live airport/flight search data with local data used by ancillary
/// UI such as the date-price strip.
final class BookingRepositoryImpl: BookingRepository {
    private let mock: BookingMockService
    private let catalogueRemote: FlightCatalogueRemoteService
    private let flightSearch: FlightSearchCallableService
    private let flightHold: FlightHoldCallableService
    private let serviceEnquiry: ServiceEnquiryCallableService
    private let runAuthenticated: AuthenticatedRequestRunner

    init(
        _ mock: BookingMockService,
        _ catalogueRemote: FlightCatalogueRemoteService,
        _ flightSearch: FlightSearchCallableService,
        _ flightHold: FlightHoldCallableService,
        _ serviceEnquiry: ServiceEnquiryCallableService,
        _ runAuthenticated: AuthenticatedRequestRunner
    ) {
        self.mock = mock
        self.catalogueRemote = catalogueRemote
        self.flightSearch = flightSearch
        self.flightHold = flightHold
        self.serviceEnquiry = serviceEnquiry
        self.runAuthenticated = runAuthenticated
    }

    func getLocations() async -> AppResult<[LocationModel]> {
        await `guard` {
            let catalogueRemote = self.catalogueRemote
            let airports = try await self.runAuthenticated { token in
                try await catalogueRemote.getActiveAirports(accessToken: token.isEmpty ? nil : token)
            }
            return .success(
                airports.map { airport in
                    LocationModel(
                        code: airport.code,
                        city: airport.cityName,
                        facilityName: airport.name,
                        country: airport.country,
                        searchCode: airport.searchCode
                    )
                }
            )
        }
    }

    func submitFlightSearch(_ request: FlightSearchRequest) async -> AppResult<[TripOptionModel]> {
        await `guard` {
            // `searchFlights` supplies live MAI inventory. The public schedule
            // catalogue provides the other airlines, which are enquiry-only.
            async let searchFuture = self.flightSearch.searchFlights(request)
            async let schedulesFuture = self.activeFlightSchedulesOrEmpty()
            async let carriersFuture = self.activeCarriersOrEmpty()
            let response = try await searchFuture
            let schedules = await schedulesFuture
            let carriers = await carriersFuture
            var carriersByCode: [String: FlightCarrierModel] = [:]
            for carrier in carriers {
                let code = carrier.code.trimmingCharacters(in: .whitespacesAndNewlines)
                if !code.isEmpty { carriersByCode[code.uppercased()] = carrier }
            }
            var carriersByName: [String: FlightCarrierModel] = [:]
            for carrier in carriers {
                let name = carrier.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { carriersByName[name.lowercased()] = carrier }
            }
            let searchDate = try DateTime.parse(request.departDate)
            let scheduleOptions = schedules
                .filter { schedule in
                    schedule.airlineCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() != "8M"
                        && schedule.operatesOn(from: request.from, to: request.to, date: searchDate)
                }
                .map { schedule -> TripOptionModel in
                    let carrier =
                        carriersByCode[schedule.airlineCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()]
                        ?? carriersByName[schedule.airlineName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
                    return schedule.toTripOption(
                        searchDate,
                        carrierLogoUrl: carrier?.logoUrl,
                        carrierName: carrier?.name
                    )
                }
            return .success(response.options + scheduleOptions)
        }
    }

    /// Dart `.onError((_, _) => const <FlightScheduleModel>[])`.
    private func activeFlightSchedulesOrEmpty() async -> [FlightScheduleModel] {
        let catalogueRemote = self.catalogueRemote
        do {
            return try await runAuthenticated { token in
                try await catalogueRemote.getActiveFlightSchedules(accessToken: token.isEmpty ? nil : token)
            }
        } catch {
            return []
        }
    }

    /// Dart `.onError((_, _) => const <FlightCarrierModel>[])`.
    private func activeCarriersOrEmpty() async -> [FlightCarrierModel] {
        let catalogueRemote = self.catalogueRemote
        do {
            return try await runAuthenticated { token in
                try await catalogueRemote.getActiveCarriers(accessToken: token.isEmpty ? nil : token)
            }
        } catch {
            return []
        }
    }

    func holdFlight(_ request: FlightHoldRequest) async -> AppResult<FlightHoldResponse> {
        await `guard` {
            let flightHold = self.flightHold
            let response = try await self.runAuthenticated { token in
                try await flightHold.holdFlight(request: request, accessToken: token.isEmpty ? nil : token)
            }
            if !response.ok {
                return .failure(
                    .server(message: !response.message.isEmpty ? response.message : response.reason)
                )
            }
            return .success(response)
        }
    }

    func createServiceEnquiry(_ request: ServiceEnquiryRequest) async -> AppResult<ServiceEnquirySubmission> {
        await `guard` {
            let serviceEnquiry = self.serviceEnquiry
            let response = try await self.runAuthenticated { token in
                try await serviceEnquiry.create(request: request, accessToken: token)
            }
            if response.id.isEmpty {
                return .failure(.server(message: "The enquiry was not accepted. Please try again."))
            }
            return .success(response)
        }
    }

    func getMyServiceEnquiries(userId: String, email: String) async -> AppResult<[ServiceEnquiryModel]> {
        await `guard` {
            let serviceEnquiry = self.serviceEnquiry
            let enquiries = try await self.runAuthenticated { token in
                try await serviceEnquiry.getMine(userId: userId, email: email, accessToken: token)
            }
            return .success(enquiries)
        }
    }

    func searchTrips(
        mode: TravelMode,
        date: DateTime,
        from: LocationModel,
        to: LocationModel
    ) async -> AppResult<[TripOptionModel]> {
        await `guard` {
            // Dart's own pending-API note: POST Endpoints.searchTrips with the
            // criteria. Until then trips come from the mock service, as in Dart.
            .success(self.mock.searchTrips(mode: mode, date: date, from: from, to: to))
        }
    }

    func getDailyMinPrices(
        mode: TravelMode,
        from: LocationModel,
        to: LocationModel,
        around: DateTime,
        windowDays: Int
    ) async -> AppResult<[DateTime: Double]> {
        await `guard` {
            let anchor = DateTime(around.year, around.month, around.day)
            var prices: [DateTime: Double] = [:]
            for offset in -2...windowDays {
                let day = anchor.add(Duration(days: offset))
                let trips = self.mock.searchTrips(mode: mode, date: day, from: from, to: to)
                if trips.isEmpty { continue }
                prices[day] = trips.map(\.price).reduce(trips[0].price) { a, b in a < b ? a : b }
            }
            return .success(prices)
        }
    }

    /// Dart `_guard`: any error the body throws becomes a mapped failure.
    private func `guard`<T>(_ body: () async throws -> AppResult<T>) async -> AppResult<T> {
        do {
            return try await body()
        } catch {
            return .failure(FailureMapper.from(error))
        }
    }
}
