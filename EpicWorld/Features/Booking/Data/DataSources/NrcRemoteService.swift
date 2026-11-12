// Port of lib/features/booking/data/datasources/nrc_remote_service.dart

import Foundation

/// Reads the NRC reference data used by the traveller details form.
final class NrcRemoteService {
    private let functions: CallableInvoking

    init(_ functions: CallableInvoking) {
        self.functions = functions
    }

    func getNrcCodes(accessToken: String? = nil) async throws -> [NrcCode] {
        let payload = try await execute(operation: "ListNrcCodes", accessToken: accessToken)
        var codes = items(payload, "nrcCodes")
            .map { NrcCode.fromJson($0) }
            .filter { !$0.code.isEmpty }
        codes.sort { NrcCode.compareByCode($0, $1) < 0 }
        return codes
    }

    func getNrcTownships(nrcCode: String, accessToken: String? = nil) async throws -> [NrcTownship] {
        let payload = try await execute(
            operation: "ListNrcTownshipsByCode",
            variables: ["nrcCode": nrcCode],
            accessToken: accessToken
        )
        return items(payload, "nrcTownships")
            .map { NrcTownship.fromJson($0) }
            .filter { !$0.short.isEmpty }
    }

    private func execute(
        operation: String,
        variables: JSON = [:],
        accessToken: String?
    ) async throws -> JSON {
        let result = try await functions.call(
            F.functionsUrl(Endpoints.dcExec),
            [
                "operation": operation,
                "variables": variables,
                "accessToken": (accessToken as Any?) ?? NSNull(),
            ] as JSON
        )
        return try ApiException.callablePayload(result, endpoint: "\(Endpoints.dcExec)/\(operation)")
    }

    private func items(_ payload: JSON, _ field: String) -> [JSON] {
        Dart.maps(payload[field])
    }
}
