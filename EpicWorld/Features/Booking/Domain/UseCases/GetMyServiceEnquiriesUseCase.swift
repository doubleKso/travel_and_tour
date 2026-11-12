// Port of lib/features/booking/domain/usecases/get_my_service_enquiries_use_case.dart

import Foundation

/// The current customer's airline enquiries.
final class GetMyServiceEnquiriesUseCase: UseCase {
    private let repository: BookingRepository

    init(_ repository: BookingRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: GetMyServiceEnquiriesParams) async -> AppResult<[ServiceEnquiryModel]> {
        await repository.getMyServiceEnquiries(userId: params.userId, email: params.email)
    }
}

/// Dart record `({String userId, String email})`.
typealias GetMyServiceEnquiriesParams = (userId: String, email: String)
