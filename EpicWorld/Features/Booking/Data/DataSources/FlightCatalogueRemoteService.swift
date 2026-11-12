// Port of lib/features/booking/data/datasources/flight_catalogue_remote_service.dart

import Foundation

/// Reads the public flight reference catalogue through the shared `dcExec`
/// callable. These operations are available to guests as well as members.
final class FlightCatalogueRemoteService {
    private let functions: CallableInvoking

    init(_ functions: CallableInvoking) {
        self.functions = functions
    }

    func getActiveAirports(accessToken: String? = nil) async throws -> [AirportModel] {
        let payload = try await execute(operation: "ListActiveAirports", accessToken: accessToken)
        return items(payload, "places").map { AirportModel.fromJson($0) }
    }

    func getActiveCountries(accessToken: String? = nil) async throws -> [AirportCountryModel] {
        let payload = try await execute(operation: "ListActiveCountries", accessToken: accessToken)
        return items(payload, "countries").map { AirportCountryModel.fromJson($0) }
    }

    func getActiveAirportCities(accessToken: String? = nil) async throws -> [AirportCityModel] {
        let payload = try await execute(operation: "ListActiveAirportCities", accessToken: accessToken)
        return items(payload, "airportCities").map { AirportCityModel.fromJson($0) }
    }

    func getActiveCarriers(accessToken: String? = nil) async throws -> [FlightCarrierModel] {
        let payload = try await execute(operation: "ListActiveCarriers", accessToken: accessToken)
        return items(payload, "carriers").map { FlightCarrierModel.fromJson($0) }
    }

    func getActiveFlightSchedules(accessToken: String? = nil) async throws -> [FlightScheduleModel] {
        let payload = try await execute(operation: "ListActiveFlightSchedules", accessToken: accessToken)
        return items(payload, "flightSchedules").map { FlightScheduleModel.fromJson($0) }
    }

    private func execute(operation: String, accessToken: String?) async throws -> JSON {
        let request: JSON = [
            "operation": operation,
            "variables": JSON(),
            // Use the same callable contract as notifications. The public endpoint
            // receives null for guests and the current token for members.
            "accessToken": (accessToken as Any?) ?? NSNull(),
        ]
        let result = try await functions.call(F.functionsUrl(Endpoints.dcExec), request)
        return try ApiException.callablePayload(result, endpoint: "\(Endpoints.dcExec)/\(operation)")
    }

    private func items(_ payload: JSON, _ field: String) -> [JSON] {
        Dart.maps(payload[field])
    }

    func getGlobalAirlineRates(accessToken: String? = nil) async throws -> [GlobalAirlineRateModel] {
        let payload = try await execute(operation: "GetGlobalAirlineRates", accessToken: accessToken)
        return items(payload, "globalAirlineRates").map { GlobalAirlineRateModel.fromJson($0) }
    }

    func getTierAirlineRates(accessToken: String? = nil) async throws -> [TierAirlineRateModel] {
        let payload = try await execute(operation: "GetTierAirlineRates", accessToken: accessToken)
        return items(payload, "tierAirlineRates").map { TierAirlineRateModel.fromJson($0) }
    }

    func getActiveTierBenefits(accessToken: String? = nil) async throws -> [TierBenefitModel] {
        let payload = try await execute(operation: "GetActiveTierBenefits", accessToken: accessToken)
        return items(payload, "tierBenefits").map { TierBenefitModel.fromJson($0) }
    }
}
