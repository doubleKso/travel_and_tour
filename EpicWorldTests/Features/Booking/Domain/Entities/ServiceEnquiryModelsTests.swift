import XCTest
@testable import EpicWorld

/// Port of test/features/booking/domain/entities/service_enquiry_models_test.dart.
final class ServiceEnquiryModelsTests: XCTestCase {
    func testSerializesTheCreateServiceEnquiryCallableVariables() {
        let request = ServiceEnquiryRequest(
            service: "flight",
            refId: "schedule-MNA-RGN-MDL",
            refName: "Myanmar National Airlines MNA · RGN → MDL · 11:00 AM",
            name: "Platform Admin",
            email: "admin@epic-world.com",
            phone: "+959680149352",
            preferredDate: "2026-08-27",
            pax: 1,
            message: "",
            userId: "user-1"
        )

        XCTAssertEqual(
            NSDictionary(dictionary: request.toJson()),
            NSDictionary(dictionary: [
                "service": "flight",
                "refId": "schedule-MNA-RGN-MDL",
                "refName": "Myanmar National Airlines MNA · RGN → MDL · 11:00 AM",
                "name": "Platform Admin",
                "email": "admin@epic-world.com",
                "phone": "+959680149352",
                "preferredDate": "2026-08-27",
                "pax": 1,
                "message": "",
                "userId": "user-1",
            ])
        )
    }

    func testMapsServiceEnquiryCreateAndHistoryResponses() {
        let submitted = ServiceEnquirySubmission.fromJson([
            "id": "0e649d25b585401c98bede743b935feb",
        ])
        let enquiry = ServiceEnquiryModel.fromJson([
            "id": submitted.id,
            "service": "flight",
            "refId": NSNull(),
            "refName": "Myanmar National Airlines MNA · RGN → MDL · 11:00",
            "name": "Platform Admin",
            "email": "admin@epic-world.com",
            "phone": "+959680149352",
            "preferredDate": "2026-08-27",
            "pax": 1,
            "message": NSNull(),
            "status": "new",
            "createdAt": "2026-08-26T03:50:59.793271Z",
        ])

        XCTAssertEqual(submitted.id, "0e649d25b585401c98bede743b935feb")
        XCTAssertTrue(enquiry.refId.isEmpty)
        XCTAssertEqual(enquiry.pax, 1)
        XCTAssertEqual(enquiry.status, "new")
        XCTAssertNotNil(enquiry.createdAt)
    }
}
