// Port of lib/features/member/data/repositories/member_repository_impl.dart
import Foundation

final class MemberRepositoryImpl: MemberRepository {
    private let mock: MemberMockService

    init(_ mock: MemberMockService) {
        self.mock = mock
    }

    func getBenefits() async -> AppResult<[MemberBenefit]> {
        // Dart marks this for the API: GET Endpoints.memberBenefits via
        // MemberRemoteService. Dart wraps the mock read in
        // `catch (e) → UnexpectedFailure(e.toString())`; the Swift mock
        // cannot throw, so there is nothing to catch.
        return .success(mock.getBenefits())
    }

    func getPartners() async -> AppResult<[PartnerBrand]> {
        // Dart marks this for the API: GET Endpoints.memberPartners via
        // MemberRemoteService. (Same non-throwing mock read as above.)
        return .success(mock.getPartners())
    }
}
