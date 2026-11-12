// Port of lib/features/member/domain/repositories/member_repository.dart
import Foundation

/// Read side of the loyalty programme.
protocol MemberRepository: AnyObject {
    func getBenefits() async -> AppResult<[MemberBenefit]>

    func getPartners() async -> AppResult<[PartnerBrand]>
}
