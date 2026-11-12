import Foundation

/// Every screen in the app — the port of lib/app/router/app_router.dart.
///
/// Each auto_route `XxxRoute(args)` is a case `.xxx(args)` with the same
/// argument labels and defaults, so navigation ports verbatim:
///
/// | Dart                                                  | Swift                                             |
/// |-------------------------------------------------------|---------------------------------------------------|
/// | `context.router.push(HotelDetailRoute(category: c))`  | `router.push(.hotelDetail(category: c))`          |
/// | `await context.router.push<LocationModel>(LocationPickerRoute(title: t))` | `await router.pushForResult(.locationPicker(title: t), as: LocationModel.self)` |
/// | `await context.router.push(const BookingDetailRoute())` | `await router.pushAndWait(.bookingDetail)`      |
/// | `context.router.replaceAll([const MainShellRoute()])` | `router.replaceAll([.mainShell])`                 |
/// | `context.router.current.name == LoginRoute.name`      | `router.currentName == Route.loginName`           |
///
/// Page structs take the same arguments, in `RouteView`.
enum Route {
    // ---- Entry ---------------------------------------------------------
    case welcome(onGetStarted: (() -> Void)? = nil)
    case mainShell

    // ---- Auth ----------------------------------------------------------
    case login(popOnSuccess: Bool = false)
    case signUp
    case emailVerification(userId: String, email: String)
    /// Two-step checkpoint for accounts with two-factor authentication on.
    case twoStepVerification(userId: String, email: String)
    /// Forgot password: email a reset code, then choose a new password.
    case forgotPassword(email: String = "")
    case resetPassword(email: String)

    // ---- Home ----------------------------------------------------------
    case home
    case commercialFlight

    // ---- Booking flow --------------------------------------------------
    case searchResults
    case bookingDetail
    case payment
    /// Landing route for the backend's SMARTPAY_RETURN_URL.
    case paymentReturn
    case bookingCompleted(ticket: TicketModel)
    case locationPicker(title: String, exclude: LocationModel? = nil)
    /// Guest booking recovery: the reference/email pair from a confirmation
    /// email, or the bookings this device remembers.
    case findMyBooking
    /// Transparent overlay drawn on top of the results list while the search
    /// animation plays (auto_route `CustomRoute(opaque: false)` with a fade).
    case flightSearchLoading(from: LocationModel, to: LocationModel)

    // ---- Tickets -------------------------------------------------------
    case tickets(onBack: (() -> Void)? = nil)
    case history(onBack: (() -> Void)? = nil)
    case ticketDetail(ticket: TicketModel)
    case reservationDetail(reservation: TicketModel)
    case boardingPass(ticket: TicketModel)

    // ---- Catalogue -----------------------------------------------------
    case hotel
    case hotelDetail(category: HotelCategory)
    case tour
    case tourDetail(tour: TourPackage)
    case visa
    /// Country profile + the visa types we handle there.
    case visaCountry(slug: String, countryName: String? = nil, flagUrl: String? = nil, flagCode: String? = nil)

    // ---- Member & profile ----------------------------------------------
    case member(onBack: (() -> Void)? = nil)
    case profile(onBack: (() -> Void)? = nil)
    case manageProfile
    case changePassword
    case language
    case helpCenter
    case about

    // ---- Notifications --------------------------------------------------
    case notifications
    case notificationSettings
}

extension Route {
    /// Drawn as a transparent overlay above the stack instead of being pushed.
    var isOverlay: Bool {
        if case .flightSearchLoading = self { return true }
        return false
    }

    /// auto_route's generated route name (`LoginRoute.name`).
    var name: String {
        switch self {
        case .welcome: return "WelcomeRoute"
        case .mainShell: return "MainShellRoute"
        case .login: return Route.loginName
        case .signUp: return "SignUpRoute"
        case .emailVerification: return "EmailVerificationRoute"
        case .twoStepVerification: return "TwoStepVerificationRoute"
        case .forgotPassword: return "ForgotPasswordRoute"
        case .resetPassword: return "ResetPasswordRoute"
        case .home: return "HomeRoute"
        case .commercialFlight: return "CommercialFlightRoute"
        case .searchResults: return "SearchResultsRoute"
        case .bookingDetail: return "BookingDetailRoute"
        case .payment: return Route.paymentName
        case .paymentReturn: return "PaymentReturnRoute"
        case .bookingCompleted: return "BookingCompletedRoute"
        case .locationPicker: return "LocationPickerRoute"
        case .findMyBooking: return "FindMyBookingRoute"
        case .flightSearchLoading: return "FlightSearchLoadingRoute"
        case .tickets: return "TicketsRoute"
        case .history: return "HistoryRoute"
        case .ticketDetail: return "TicketDetailRoute"
        case .reservationDetail: return "ReservationDetailRoute"
        case .boardingPass: return "BoardingPassRoute"
        case .hotel: return "HotelRoute"
        case .hotelDetail: return "HotelDetailRoute"
        case .tour: return "TourRoute"
        case .tourDetail: return "TourDetailRoute"
        case .visa: return "VisaRoute"
        case .visaCountry: return "VisaCountryRoute"
        case .member: return "MemberRoute"
        case .profile: return "ProfileRoute"
        case .manageProfile: return "ManageProfileRoute"
        case .changePassword: return "ChangePasswordRoute"
        case .language: return "LanguageRoute"
        case .helpCenter: return "HelpCenterRoute"
        case .about: return "AboutRoute"
        case .notifications: return "NotificationsRoute"
        case .notificationSettings: return "NotificationSettingsRoute"
        }
    }

    static let loginName = "LoginRoute"
    static let paymentName = "PaymentRoute"

    /// The route's path in the Dart route table.
    var path: String {
        switch self {
        case .welcome: return "/"
        case .mainShell: return "/home"
        case .login: return "/login"
        case .signUp: return "/sign-up"
        case .emailVerification: return "/verify-email"
        case .twoStepVerification: return "/verify-sign-in"
        case .forgotPassword: return "/forgot-password"
        case .resetPassword: return "/reset-password"
        case .home: return "/home/search"
        case .commercialFlight: return "/commercial-flights"
        case .searchResults: return "/booking/results"
        case .bookingDetail: return "/booking/detail"
        case .payment: return "/booking/payment"
        case .paymentReturn: return PaymentReturnPage.routePath
        case .bookingCompleted: return "/booking/completed"
        case .locationPicker: return "/booking/locations"
        case .findMyBooking: return "/booking/manage"
        case .flightSearchLoading: return "/booking/searching"
        case .tickets: return "/tickets"
        case .history: return "/tickets/history"
        case .ticketDetail: return "/tickets/detail"
        case .reservationDetail: return "/tickets/reservation"
        case .boardingPass: return "/tickets/boarding-pass"
        case .hotel: return "/hotels"
        case .hotelDetail: return "/hotels/detail"
        case .tour: return "/tours"
        case .tourDetail: return "/tours/detail"
        case .visa: return "/visa"
        case .visaCountry(let slug, _, _, _): return "/visa/\(slug)"
        case .member: return "/member"
        case .profile: return "/profile"
        case .manageProfile: return "/profile/manage"
        case .changePassword: return "/profile/password"
        case .language: return "/profile/language"
        case .helpCenter: return "/profile/help"
        case .about: return "/profile/about"
        case .notifications: return "/notifications"
        case .notificationSettings: return "/notifications/settings"
        }
    }
}
