// Port of lib/features/ticket/domain/entities/history_eticket.dart
import Foundation

/// Rebuilds the shared e-ticket view model from the signed-in customer's
/// booking-history API records. This keeps History's document visually and
/// semantically identical to the ticket shown after a payment succeeds.
enum HistoryETicket {
    static func from(
        _ booking: BookingHistoryItem,
        _ detail: BookingHistoryDetail
    ) -> TicketModel {
        let itinerary = HeldBookingResume.from(booking, segments: detail.segments)
        let phone = [booking.contactCountryCode, booking.contactPhone]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " ")
        let passengers = detail.passengers.map { passenger in
            TicketPassenger(
                title: passenger.title,
                firstName: passenger.firstName,
                lastName: passenger.lastName,
                type: passenger.type,
                nrc: passenger.nrc,
                passportNo: passenger.passportNo,
                phone: phone
            )
        }
        let trimmedReference = booking.reference.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPnr = booking.pnr.trimmingCharacters(in: .whitespacesAndNewlines)
        let reference = !trimmedReference.isEmpty
            ? trimmedReference
            : (!trimmedPnr.isEmpty ? trimmedPnr : booking.id)
        let passengerName = passengers
            .map(\.fullName)
            .first(where: { !$0.isEmpty })
            ?? "\(booking.contactTitle) \(booking.contactFullName)".trimmingCharacters(in: .whitespacesAndNewlines)

        return TicketModel(
            id: !booking.id.isEmpty ? booking.id : reference,
            bookingReference: reference,
            outbound: itinerary.outbound,
            inbound: itinerary.inbound,
            passengerName: !passengerName.isEmpty ? passengerName : "Passenger",
            seatCount: !passengers.isEmpty
                ? passengers.count
                : (booking.passengerCount > 0 ? booking.passengerCount : 1),
            totalPaid: booking.total,
            currency: booking.currency,
            issuedAt: booking.ticketedAt?.toLocal()
                ?? booking.createdAt?.toLocal()
                ?? itinerary.departDate,
            qrPayload: [booking.pnr, reference]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: "|"),
            pnr: trimmedPnr,
            contactName: booking.contactFullName.trimmingCharacters(in: .whitespacesAndNewlines),
            passengers: passengers,
            // The booking record keeps the promo's amount but not its code.
            discount: booking.promotion > 0 ? booking.promotion : 0,
            promotion: booking.promotion > 0 ? booking.promotion : 0
        )
    }
}
