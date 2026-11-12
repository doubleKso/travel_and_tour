// Port of lib/features/ticket/presentation/pdf/eticket_info.dart
import Foundation

/// Single source of truth for the E-Ticket **Important Information** content,
/// shared by the in-app e-ticket card and the printable PDF so the two never
/// drift apart. Each entry is `[title, body]`; the body uses a tiny markup that
/// both renderers understand:
///
///   `- `   → bullet (level 1)
///   `-- `  → sub-bullet (level 2)
///   `! `   → italic "important note" line
///   (plain) → paragraph line
///
/// URL-looking tokens (`http…`, `www…`, `*.com`, `*.htm`) are highlighted in the
/// brand colour by both renderers.
///
/// (Multi-line literals: a trailing `\` joins two source lines, a plain line
/// break is the body's `\n`.)
let kImportantInfoSections: [[String]] = [
    [
        "Ticket",
        "This ticket is non-transferable and valid on airline flights only.",
    ],
    [
        "Reconfirmation & Date Change",
        "Subject to booking conditions, refer to the airline's Terms & Conditions.",
    ],
    [
        "General Terms & Conditions & Liability Limitations",
        """
        General Terms & Conditions (General T&Cs) and Passenger & Baggage Liability \
        Limitations, please refer to:
        - https://www.maiair.com/plan-your-journey/terms-conditions
        - https://www.maiair.com/plan-your-journey/general-conditions-of-carriage
        """,
    ],
    [
        "Customize Your Journey with Add-Ons",
        """
        Refer to the "Add-On" section in https://www.maiair.com
        - Paid add-ons:
        -- Flight-related: Extra Baggage, Seat Selection, Meal Selection
        -- Ground-related: Mai Hsoong Kha Services VIP Service & Wheelchair Service
        - Paid e-visa services are also available: https://apply.joinsherpa.com
        """,
    ],
    [
        "Checked Free Baggage Allowance (FBA)",
        """
        - International — All Sectors [Except: Seoul-Incheon (ICN)]:
        -- Business: 40KG (max. 2 pieces & not exceeding 23KG per piece)
        -- Economy — "L", "N" & "S" Class: 20KG (max. 2 pieces & not exceeding 20KG per piece); Other Fare Classes: 30KG (max. 2 pieces & not exceeding 30KG per piece)
        -- Infant: 10KG (max. 1 piece & not exceeding 10KG per piece)
        -- Size limit: 56cm × 36cm × 23cm
        - International — Seoul-Incheon (ICN):
        -- Business: 64KG (max. 2 pieces & not exceeding 32KG per piece)
        -- Economy: 23KG (max. 1 piece & not exceeding 23KG)
        -- Infant: 10KG (max. 1 piece & not exceeding 10KG per piece) · Size limit: 56cm × 36cm × 23cm
        - Domestic — All Sectors:
        -- Business: 30KG (max. 2 pieces & not exceeding 30KG per piece)
        -- Economy: 20KG (max. 2 pieces & not exceeding 20KG per piece)
        -- Infant: 10KG (max. 1 piece & not exceeding 10KG per piece) · Size limit: 56cm × 36cm × 23cm
        ! Important Note: Refer to the Baggage Allowance at E-Ticket receipt for eligible FBA.
        """,
    ],
    [
        "Cabin / Carry-On Baggage",
        """
        - International — Business: 14KG (max. 2 pieces & not exceeding 7KG per piece); Economy: 7KG (max. 1 piece & not exceeding 7KG per piece) · Size limit: 56cm × 36cm × 23cm
        - Domestic — 7KG (max. 1 piece & not exceeding 7KG per piece) · Size limit: 56cm × 36cm × 22cm
        """,
    ],
    [
        "Check-In",
        """
        - International [Except Guangzhou (CAN)]: Check-in counter opens 3 hours & closes 45 minutes before departure. Guangzhou (CAN): opens 3 hours & closes 1 hour before departure. Boarding gate opens 1 hour 15 minutes & closes 10 minutes before departure.
        - Domestic — ATR72-600: Check-in opens 2 hours & closes 30 minutes before departure. E190/A319/A320: Check-in opens 2 hours 30 minutes & closes 30 minutes before departure. Boarding gate opens 1 hour 15 minutes & closes 10 minutes before departure.
        ! Important Note: Airline will not be responsible for late reporting of passengers.
        """,
    ],
    [
        "Traveling Documents",
        """
        Travellers must ensure that their passport, health requirements, visas & other \
        necessary documents are valid and meet the immigration requirements at the \
        departure and destination airports. Failure to pass the check-in counter or \
        report for boarding due to non-compliance with immigration requirements will \
        cause the offloading of passengers and baggage from the flight without any \
        claim or responsibility against the airline & ticket conditions. Passengers \
        should carry a copy of this booking confirmation while travelling, as it may \
        be required for immigration purposes.
        """,
    ],
    [
        "Use of Flight Coupons and Sequence",
        """
        The flight coupons must be used in the sequence printed in the passenger coupon \
        of the ticket. Out-of-sequence travel is not allowed. If a passenger changes \
        the itinerary, the airline will determine the fares based on the new \
        itinerary, and the passenger must pay any additional amount between the \
        original paid fare and the total fare of the new itinerary. The unused \
        coupons of passenger tickets cannot be used anymore.
        """,
    ],
    [
        "No-Show Policy",
        """
        Reporting late or failing to travel on the booked flight will be considered a \
        No-Show, and the relevant penalties as per fare rules will be applied to \
        re-booking or refunding.
        """,
    ],
    [
        "Online Ticket Policy",
        """
        To board a domestic flight, passengers who purchased the ticket from the \
        airline's official website (maiair.com) or other online booking channels \
        using their credit or debit cards are requested to present the respective \
        card(s) used to buy the ticket at the airport during check-in. If the card \
        cannot be displayed physically, the passenger must present a photo of the \
        card (front only) along with a handwritten authorization signed by the \
        cardholder to the airline representative at the airport.
        """,
    ],
    [
        "Refund Policy",
        """
        Subject to the airline's refund rules stated as part of the booking terms & \
        conditions and/or its applicable fare rules, the airline will only refund the \
        fare of the unused sector and Passenger Fuel Surcharge after deducting \
        applicable cancellation and/or no-show fees. Where the applicable \
        cancellation and/or no-show fees are higher than the fare of the unused \
        sector and Passenger Fuel Surcharge, there will be no refund and the \
        additional amount is payable by the passenger. Passengers must bear any \
        applicable fees/charges, including but not limited to payment gateway and \
        card issuer charges.
        """,
    ],
    [
        "Conditions of Carriage",
        """
        Carriage and other services provided by the airline are subject to the \
        airline's Conditions of Carriage, which are incorporated by reference. The \
        Conditions of Carriage may be obtained from the issuing airline.
        """,
    ],
    [
        "Power Bank Restrictions",
        """
        Passengers are strictly prohibited from using and charging power banks during \
        flight. Only two (2) power banks up to 100Wh, or one (1) power bank of \
        100Wh–160Wh, may be carried per passenger and must be transported in \
        carry-on baggage. Power banks must not be placed in overhead compartments — \
        they must be stored in carry-on baggage under the seat or in the seat pocket \
        in front of the passenger. Any damaged, swollen or non-compliant power banks \
        are not allowed on flights.
        """,
    ],
    [
        "Data Protection Policy",
        """
        Passenger data is processed per the privacy policy of the applicable airline's \
        reservation system provider ("PSS") or relevant distribution channel(s) \
        where the booking is made. This information is available at \
        www.iatatravelcenter.com/privacy.htm or from the carrier or GDS directly. \
        Passengers are strongly recommended to review this information, which \
        indicates how data is collected, stored, used, disclosed & transferred.
        """,
    ],
]
