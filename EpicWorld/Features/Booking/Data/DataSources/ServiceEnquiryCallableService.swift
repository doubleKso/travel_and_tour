// Port of lib/features/booking/data/datasources/service_enquiry_callable_service.dart

import Foundation

/// Service-enquiry access for airlines that cannot be booked directly.
final class ServiceEnquiryCallableService {
    private let functions: CallableInvoking

    init(_ functions: CallableInvoking) {
        self.functions = functions
    }

    func create(request: ServiceEnquiryRequest, accessToken: String) async throws -> ServiceEnquirySubmission {
        let payload = try await execute(
            operation: "CreateServiceEnquiry",
            accessToken: accessToken,
            variables: request.toJson()
        )
        guard let raw = Dart.map(payload["serviceEnquiry_insert"]) else {
            throw FormatException("Invalid service-enquiry response.")
        }
        return ServiceEnquirySubmission.fromJson(raw)
    }

    func getMine(userId: String, email: String, accessToken: String) async throws -> [ServiceEnquiryModel] {
        let payload = try await execute(
            operation: "GetMyServiceEnquiries",
            accessToken: accessToken,
            variables: ["userId": userId, "email": email]
        )
        return Dart.maps(payload["serviceEnquiries"]).map { ServiceEnquiryModel.fromJson($0) }
    }

    private func execute(
        operation: String,
        accessToken: String,
        variables: JSON
    ) async throws -> JSON {
        let result = try await functions.call(
            F.functionsUrl(Endpoints.dcExec),
            [
                "operation": operation,
                "variables": variables,
                "accessToken": accessToken,
            ] as JSON
        )
        return try ApiException.callablePayload(result, endpoint: "\(Endpoints.dcExec)/\(operation)")
    }
}
