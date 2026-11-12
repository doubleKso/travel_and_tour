// Port of lib/features/visa/data/datasources/visa_remote_service.dart

import Foundation

/// Reads the public visa catalogue through the `dcExec` callable. Every
/// operation supports guests (`accessToken: nil`) and authenticated members.
final class VisaRemoteService {
    private let functions: CallableInvoking

    init(_ functions: CallableInvoking) {
        self.functions = functions
    }

    func getActiveVisaCountries(accessToken: String? = nil) async throws -> [VisaCountryModel] {
        let payload = try await execute(
            operation: "ListActiveVisaCountries",
            accessToken: accessToken
        )
        return items(payload, "visaCountries").map(VisaCountryModel.fromJson)
    }

    func getPublishedVisaTypeCountries(accessToken: String? = nil) async throws -> [VisaTypeCountryModel] {
        let payload = try await execute(
            operation: "ListPublishedVisaTypeCountries",
            accessToken: accessToken
        )
        return items(payload, "visaTypes").map(VisaTypeCountryModel.fromJson)
    }

    /// Full profile for one destination. Returns nil when the slug is not in
    /// the catalogue, which the country screen renders as "not found" rather
    /// than as a failure.
    func getVisaCountryBySlug(slug: String, accessToken: String? = nil) async throws -> VisaCountryDetail? {
        let payload = try await execute(
            operation: "GetVisaCountryBySlug",
            accessToken: accessToken,
            variables: ["slug": slug]
        )
        let found = items(payload, "visaCountries")
        return found.isEmpty ? nil : VisaCountryDetail.fromJson(found[0])
    }

    /// Visa types the desk handles for one country, keyed by the country ID the
    /// slug lookup returned.
    func getVisaTypes(countryId: String, accessToken: String? = nil) async throws -> [VisaTypeModel] {
        let payload = try await execute(
            operation: "GetVisaTypes",
            accessToken: accessToken,
            variables: ["countryId": countryId]
        )
        return items(payload, "visaTypes").map(VisaTypeModel.fromJson)
    }

    private func execute(
        operation: String,
        accessToken: String?,
        variables: JSON = [:]
    ) async throws -> JSON {
        let body: JSON = [
            "operation": operation,
            "variables": variables,
            // Dart sends an explicit `null` for guests.
            "accessToken": (accessToken as Any?) ?? NSNull(),
        ]
        let result = try await functions.call(F.functionsUrl(Endpoints.dcExec), body)
        return try ApiException.callablePayload(
            result,
            endpoint: "\(Endpoints.dcExec)/\(operation)"
        )
    }

    private func items(_ payload: JSON, _ field: String) -> [JSON] {
        Dart.maps(payload[field])
    }
}
