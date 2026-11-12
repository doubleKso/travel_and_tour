// Port of lib/features/member/data/datasources/member_remote_service.dart
import Foundation

/// Public loyalty catalogue exposed by the shared `dcExec` callable.
final class MemberRemoteService {
    private let functions: CallableInvoking

    init(_ functions: CallableInvoking) {
        self.functions = functions
    }

    func getDiscountTiers(accessToken: String) async throws -> [DiscountTier] {
        items(
            try await execute(operation: "GetDiscountTiers", accessToken: accessToken),
            "discountTiers"
        ).map(DiscountTier.fromJson)
    }

    func getMyPoints(accessToken: String) async throws -> MemberPointBalance {
        let endpoint = Endpoints.myPoints
        let body: JSON = ["accessToken": accessToken]
        let response = try await call(endpoint: endpoint, body: body)
        return MemberPointBalance.fromJson(response)
    }

    func redeemPoints(_ request: RedeemPointsRequest) async throws -> RedeemPointsResponse {
        let response = try await call(
            endpoint: Endpoints.redeemPoints,
            body: request.toJson()
        )
        return RedeemPointsResponse.fromJson(response)
    }

    func getMembershipTiers(accessToken: String? = nil) async throws -> [MembershipTierData] {
        var tiers = items(
            try await execute(
                operation: "GetMembershipTiers",
                accessToken: accessToken
            ),
            "membershipTiers"
        ).map(MembershipTierData.fromJson)
        tiers.sort { $0.rank < $1.rank }
        return tiers
    }

    func getActiveTierBenefits(accessToken: String? = nil) async throws -> [TierBenefitModel] {
        items(
            try await execute(
                operation: "GetActiveTierBenefits",
                accessToken: accessToken
            ),
            "tierBenefits"
        ).map(TierBenefitModel.fromJson)
    }

    func getActiveTierPerks(accessToken: String? = nil) async throws -> [TierPerkModel] {
        items(
            try await execute(
                operation: "GetActiveTierPerks",
                accessToken: accessToken
            ),
            "tierPerks"
        ).map(TierPerkModel.fromJson)
    }

    func getMe(userId: String, accessToken: String) async throws -> MemberAccount {
        let payload = try await execute(
            operation: "GetMe",
            accessToken: accessToken,
            variables: ["id": userId]
        )
        guard let raw = Dart.map(payload["appUser"]) else {
            throw FormatException("Invalid member profile response.")
        }
        return MemberAccount.fromJson(raw)
    }

    func getMyPointLedger(userId: String, accessToken: String) async throws -> [PointLedgerTransaction] {
        items(
            try await execute(
                operation: "GetMyPointLedger",
                accessToken: accessToken,
                variables: ["userId": userId]
            ),
            "pointTransactions"
        ).map(PointLedgerTransaction.fromJson)
    }

    func getGlobalAirlineRates(accessToken: String? = nil) async throws -> [GlobalAirlineRateModel] {
        items(
            try await execute(
                operation: "GetGlobalAirlineRates",
                accessToken: accessToken
            ),
            "globalAirlineRates"
        ).map(GlobalAirlineRateModel.fromJson)
    }

    func getTierAirlineRates(accessToken: String? = nil) async throws -> [TierAirlineRateModel] {
        items(
            try await execute(operation: "GetTierAirlineRates", accessToken: accessToken),
            "tierAirlineRates"
        ).map(TierAirlineRateModel.fromJson)
    }

    private func execute(
        operation: String,
        accessToken: String?,
        variables: JSON = [:]
    ) async throws -> JSON {
        try await call(
            endpoint: Endpoints.dcExec,
            body: [
                "operation": operation,
                "variables": variables,
                // Dart sends an explicit `null` for a guest.
                "accessToken": accessToken.map { $0 as Any } ?? NSNull(),
            ],
            logName: "\(Endpoints.dcExec):\(operation)"
        )
    }

    private func call(
        endpoint: String,
        body: JSON,
        logName: String? = nil
    ) async throws -> JSON {
        let url = F.functionsUrl(endpoint)
        let name = logName ?? endpoint
        Self.log(name, "request", ["url": url, "data": Self.redact(body) ?? NSNull()])
        do {
            let data = try await functions.call(url, body)
            Self.log(name, "response", Self.redact(data))
            return try ApiException.callablePayload(data, endpoint: name)
        } catch {
            Self.log(name, "error", ["message": String(describing: error)])
            throw error
        }
    }

    private static func log(_ endpoint: String, _ direction: String, _ value: Any?) {
        #if DEBUG
        // `JsonEncoder.withIndent('  ').convert(value)`, falling back to
        // `value.toString()` when the value is not encodable.
        let output: String
        if let object = value,
           JSONSerialization.isValidJSONObject(object),
           let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
           let text = String(data: data, encoding: .utf8) {
            output = text
        } else {
            output = Dart.interpolate(value)
        }
        superPrint(output, title: "Member \(endpoint) \(direction)", isApi: true)
        #endif
    }

    private static func redact(_ value: Any?) -> Any? {
        if let map = Dart.map(value) {
            var redacted: JSON = [:]
            for (key, element) in map {
                redacted[key] = key.lowercased() == "accesstoken"
                    ? mask(Dart.str(element))
                    : (redact(element) ?? NSNull())
            }
            return redacted
        }
        if let list = Dart.list(value) {
            return list.map { redact($0) ?? NSNull() }
        }
        return value
    }

    private static func mask(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "<empty>" }
        if value.count <= 4 { return "****" }
        return "\(value.prefix(2))…\(value.suffix(2))"
    }

    private func items(_ payload: JSON, _ field: String) -> [JSON] {
        Dart.maps(payload[field])
    }
}
