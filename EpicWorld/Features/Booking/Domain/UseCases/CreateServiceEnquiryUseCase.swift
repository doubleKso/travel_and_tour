// Port of lib/features/booking/domain/usecases/create_service_enquiry_use_case.dart

import Foundation

/// Submits an enquiry for an airline that cannot be booked in-app.
final class CreateServiceEnquiryUseCase: UseCase {
    private let repository: BookingRepository

    init(_ repository: BookingRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: ServiceEnquiryRequest) async -> AppResult<ServiceEnquirySubmission> {
        await repository.createServiceEnquiry(params)
    }
}
