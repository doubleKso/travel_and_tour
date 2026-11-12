// Port of lib/features/member/presentation/providers/member_providers.dart
import Foundation
import Observation

/// `_memberUserId(ref)` — the signed-in user's id, '' for a guest.
@MainActor
private func memberUserId(_ container: AppContainer) -> String {
    container.authNotifier.state.user?.id ?? ""
}

/// `_withMemberSession(ref, request)`: runs one member request with a live
/// access token. Watching the user id is done by each resource's
/// `dependencies:` closure (see `MemberUserIdSelection`).
@MainActor
private func withMemberSession<T>(
    _ container: AppContainer,
    _ request: @escaping (String) async throws -> T
) async throws -> T {
    _ = memberUserId(container)
    return try await container.authNotifier.withValidAccessToken { accessToken in
        try await request(accessToken)
    }
}

/// `ref.watch(authNotifierProvider.select((state) => state.user?.id ?? ''))`.
///
/// `AsyncResource` reloads whenever anything its `dependencies` closure read
/// changes, so depending on `authNotifier.state` directly would reload every
/// member resource on each auth update (loading flags, error text, a profile
/// refresh). This keeps an observable copy of the selected value that only
/// changes when the value itself does — Riverpod's `select` — and the member
/// resources depend on it instead.
@MainActor
@Observable
private final class MemberUserIdSelection {
    private(set) var value: String
    @ObservationIgnored private let select: () -> String

    init(_ select: @escaping () -> String) {
        self.select = select
        self.value = select()
        track()
    }

    private func track() {
        let current = withObservationTracking {
            select()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.track() }
        }
        if current != value { value = current }
    }
}

/// Riverpod's `asyncValue.asData?.value`: the value only while the resource
/// holds data — not after an error, and not while it reloads because a watched
/// dependency changed (a refresh keeps the data, as Riverpod's does).
private func memberAsData<T>(_ value: AsyncValue<T>) -> T? {
    if value.hasError { return nil }
    if value.isLoading && !value.isRefreshing { return nil }
    return value.valueOrNull
}

private func isAfter(_ value: DateTime?, _ reference: DateTime?) -> Bool {
    guard let value else { return false }
    guard let reference else { return true }
    return value.isAfter(reference)
}

extension AppContainer {
    /// The shared user-id selection every member resource watches. Created
    /// before the resources so its own first read of the auth state is not
    /// recorded as one of their dependencies.
    private var memberUserIdSelection: MemberUserIdSelection {
        provide { MemberUserIdSelection { [unowned self] in memberUserId(self) } }
    }

    /// `discountTierListProvider`.
    var discountTierList: AsyncResource<[DiscountTier]> {
        provide {
            let selection = memberUserIdSelection
            return AsyncResource(dependencies: { AnyHashable(selection.value) }) { [unowned self] in
                if memberUserId(self).isEmpty { return [] }
                let service = self.memberRemoteService
                return try await withMemberSession(self) { token in
                    try await service.getDiscountTiers(accessToken: token)
                }
            }
        }
    }

    /// `myPointsProvider`.
    var myPoints: AsyncResource<MemberPointBalance> {
        provide {
            let selection = memberUserIdSelection
            return AsyncResource(dependencies: { AnyHashable(selection.value) }) { [unowned self] in
                if memberUserId(self).isEmpty { return MemberPointBalance.empty() }
                let service = self.memberRemoteService
                return try await withMemberSession(self) { token in
                    try await service.getMyPoints(accessToken: token)
                }
            }
        }
    }

    /// `memberAccountProvider` — the account record backing the Member page.
    /// It is intentionally loaded through `dcExec:GetMe`, rather than reusing
    /// an older sign-in payload.
    var memberAccount: AsyncResource<MemberAccount?> {
        provide {
            let selection = memberUserIdSelection
            return AsyncResource(dependencies: { AnyHashable(selection.value) }) { [unowned self] in
                let userId = memberUserId(self)
                if userId.isEmpty { return nil }
                let service = self.memberRemoteService
                let account: MemberAccount = try await withMemberSession(self) { token in
                    try await service.getMe(userId: userId, accessToken: token)
                }
                return account
            }
        }
    }

    /// `myPointLedgerProvider` — the ledger is the authoritative history of
    /// point earning, redemptions, and expirations. Its latest balance is used
    /// on the member card below.
    var myPointLedger: AsyncResource<[PointLedgerTransaction]> {
        provide {
            let selection = memberUserIdSelection
            return AsyncResource(dependencies: { AnyHashable(selection.value) }) { [unowned self] in
                let userId = memberUserId(self)
                if userId.isEmpty { return [] }
                let service = self.memberRemoteService
                return try await withMemberSession(self) { token in
                    try await service.getMyPointLedger(userId: userId, accessToken: token)
                }
            }
        }
    }

    /// `currentMemberPointsProvider` — one points value for every
    /// account-facing screen.
    ///
    /// The most recent ledger balance is authoritative when available. `GetMe`
    /// is the fallback supplied by the same member API; the older `/myPoints`
    /// endpoint remains available for checkout redemption flows.
    var currentMemberPoints: Int {
        let auth = authNotifier.state
        if !auth.isAuthenticated { return 0 }
        let ledger = memberAsData(myPointLedger.state) ?? []
        if let first = ledger.first {
            let latest = ledger.dropFirst().reduce(first) { current, item in
                isAfter(item.createdAt, current.createdAt) ? item : current
            }
            return latest.balanceAfter
        }
        let account: MemberAccount? = memberAsData(memberAccount.state) ?? nil
        return account?.points ?? auth.points
    }

    /// `membershipTierListProvider`.
    var membershipTierList: AsyncResource<[MembershipTierData]> {
        provide {
            let selection = memberUserIdSelection
            return AsyncResource(dependencies: { AnyHashable(selection.value) }) { [unowned self] in
                let service = self.memberRemoteService
                return try await withMemberSession(self) { token in
                    try await service.getMembershipTiers(accessToken: token.isEmpty ? nil : token)
                }
            }
        }
    }

    /// `memberTierBenefitListProvider`.
    var memberTierBenefitList: AsyncResource<[TierBenefitModel]> {
        provide {
            let selection = memberUserIdSelection
            return AsyncResource(dependencies: { AnyHashable(selection.value) }) { [unowned self] in
                let service = self.memberRemoteService
                return try await withMemberSession(self) { token in
                    try await service.getActiveTierBenefits(accessToken: token.isEmpty ? nil : token)
                }
            }
        }
    }

    /// `memberTierPerkListProvider`.
    var memberTierPerkList: AsyncResource<[TierPerkModel]> {
        provide {
            let selection = memberUserIdSelection
            return AsyncResource(dependencies: { AnyHashable(selection.value) }) { [unowned self] in
                let service = self.memberRemoteService
                return try await withMemberSession(self) { token in
                    try await service.getActiveTierPerks(accessToken: token.isEmpty ? nil : token)
                }
            }
        }
    }

    /// `memberGlobalAirlineRateListProvider`.
    var memberGlobalAirlineRateList: AsyncResource<[GlobalAirlineRateModel]> {
        provide {
            let selection = memberUserIdSelection
            return AsyncResource(dependencies: { AnyHashable(selection.value) }) { [unowned self] in
                let service = self.memberRemoteService
                return try await withMemberSession(self) { token in
                    try await service.getGlobalAirlineRates(accessToken: token.isEmpty ? nil : token)
                }
            }
        }
    }

    /// `memberTierAirlineRateListProvider`.
    var memberTierAirlineRateList: AsyncResource<[TierAirlineRateModel]> {
        provide {
            let selection = memberUserIdSelection
            return AsyncResource(dependencies: { AnyHashable(selection.value) }) { [unowned self] in
                let service = self.memberRemoteService
                return try await withMemberSession(self) { token in
                    try await service.getTierAirlineRates(accessToken: token.isEmpty ? nil : token)
                }
            }
        }
    }

    /// `memberPartnerListProvider` — no partner catalogue operation is
    /// currently published, so the member screen deliberately has no partner
    /// data rather than falling back to mock brands.
    var memberPartnerList: AsyncResource<[PartnerBrand]> {
        provide { AsyncResource { [] } }
    }
}
