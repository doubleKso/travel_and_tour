// Port of lib/features/booking/domain/entities/service_enquiry_models.dart

import Foundation

/// Payload for `dcExec:CreateServiceEnquiry`.
struct ServiceEnquiryRequest: Hashable {
    let service: String
    let refId: String
    let refName: String
    let name: String
    let email: String
    let phone: String
    let preferredDate: String

    /// `CreateServiceEnquiry` validates this as an integer (even though an
    /// earlier contract example listed it as a string).
    let pax: Int
    let message: String
    let userId: String

    init(
        service: String,
        refId: String,
        refName: String,
        name: String,
        email: String,
        phone: String,
        preferredDate: String,
        pax: Int,
        message: String,
        userId: String
    ) {
        self.service = service
        self.refId = refId
        self.refName = refName
        self.name = name
        self.email = email
        self.phone = phone
        self.preferredDate = preferredDate
        self.pax = pax
        self.message = message
        self.userId = userId
    }

    func toJson() -> JSON {
        [
            "service": service,
            "refId": refId,
            "refName": refName,
            "name": name,
            "email": email,
            "phone": phone,
            "preferredDate": preferredDate,
            "pax": pax,
            "message": message,
            "userId": userId,
        ]
    }
}

/// Successful result returned by `CreateServiceEnquiry`.
struct ServiceEnquirySubmission: Hashable {
    let id: String

    init(id: String) {
        self.id = id
    }

    static func fromJson(_ json: JSON) -> ServiceEnquirySubmission {
        ServiceEnquirySubmission(id: Dart.str(json["id"]) ?? "")
    }
}

/// One enquiry returned by `dcExec:GetMyServiceEnquiries`.
struct ServiceEnquiryModel: Hashable {
    let id: String
    let service: String
    let refId: String
    let refName: String
    let name: String
    let email: String
    let phone: String
    let preferredDate: String
    let pax: Int
    let message: String?
    let status: String
    let createdAt: DateTime?

    init(
        id: String,
        service: String,
        refId: String,
        refName: String,
        name: String,
        email: String,
        phone: String,
        preferredDate: String,
        pax: Int,
        message: String? = nil,
        status: String,
        createdAt: DateTime? = nil
    ) {
        self.id = id
        self.service = service
        self.refId = refId
        self.refName = refName
        self.name = name
        self.email = email
        self.phone = phone
        self.preferredDate = preferredDate
        self.pax = pax
        self.message = message
        self.status = status
        self.createdAt = createdAt
    }

    static func fromJson(_ json: JSON) -> ServiceEnquiryModel {
        ServiceEnquiryModel(
            id: Dart.str(json["id"]) ?? "",
            service: Dart.str(json["service"]) ?? "",
            refId: Dart.str(json["refId"]) ?? "",
            refName: Dart.str(json["refName"]) ?? "",
            name: Dart.str(json["name"]) ?? "",
            email: Dart.str(json["email"]) ?? "",
            phone: Dart.str(json["phone"]) ?? "",
            preferredDate: Dart.str(json["preferredDate"]) ?? "",
            pax: Dart.int(json["pax"]) ?? 0,
            message: Dart.str(json["message"]),
            status: Dart.str(json["status"]) ?? "",
            createdAt: DateTime.tryParse(Dart.str(json["createdAt"]) ?? "")
        )
    }
}
