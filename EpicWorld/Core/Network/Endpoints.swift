import Foundation

/// Every server path the app talks to, in one place — the port of
/// lib/core/network/api_endpoints.dart.
///
/// Base URLs are per-flavor and live in `F`. Keep only route paths here.
enum Endpoints {
    // ---- Auth --------------------------------------------------------------
    static let login = "/auth/login"
    static let register = "/api/auth/register"
    static let authRegister = "/auth/register"
    static let requestOtp = "/api/auth/otp/request"
    static let verifyOtp = "/api/auth/otp/verify"
    static let changePassword = "/api/auth/change-password"
    static let profile = "/api/auth/profile"

    // ---- Booking -----------------------------------------------------------
    static let locations = "/api/booking/locations"
    static let searchTrips = "/api/booking/search"
    static let createBooking = "/api/booking"
    static let payBooking = "/api/booking/pay"

    // ---- Tickets -----------------------------------------------------------
    static let myTickets = "/api/tickets"
    static func ticketById(_ id: String) -> String { "/api/tickets/\(id)" }

    // ---- Catalogue ---------------------------------------------------------
    static let promos = "/api/promotions"
    static let hotels = "/api/hotels"
    static let hotelCategories = "/api/hotels/categories"
    static let tours = "/api/tours"
    static let visaServices = "/api/visa/services"

    // ---- Member ------------------------------------------------------------
    static let memberBenefits = "/api/member/benefits"
    static let memberPartners = "/api/member/partners"

    // ---- Notification ------------------------------------------------------
    static let notifications = "/api/notifications"
    static let notificationSettings = "/api/notifications/settings"

    // ---- Firebase Callable Functions -------------------------------------
    static let searchFlights = "/searchFlights"
    static let holdFlight = "/holdFlight"
    static let confirmTicketing = "/confirmTicketing"
    static let createPaymentIntent = "/createPaymentIntent"
    static let getPaymentStatus = "/getPaymentStatus"
    static let checkPromoCode = "/checkPromoCode"
    static let myPoints = "/myPoints"
    static let redeemPoints = "/redeemPoints"
    static let authGoogleSignin = "/authGoogleSignin"
    static let authRegisterAgent = "/authRegisterAgent"
    static let authSignup = "/authSignup"
    static let authVerifyOtp = "/authVerifyOtp"
    static let authResendOtp = "/authResendOtp"
    // Two-step sign-in: `authSignin` emails a code when the account has
    // two-factor authentication on, and these answer it.
    static let authVerifyLoginOtp = "/authVerifyLoginOtp"
    static let authResendLoginOtp = "/authResendLoginOtp"
    static let authSignout = "/authSignout"
    static let authSignin = "/authSignin"
    static let authChangePassword = "/authChangePassword"
    // Forgot password: email a reset code, then set a new password with it.
    static let authRequestPasswordOtp = "/authRequestPasswordOtp"
    static let authResetPasswordWithOtp = "/authResetPasswordWithOtp"
    static let authRefresh = "/authRefresh"
    static let authUploadAvatar = "/authUploadAvatar"
    static let authMe = "/authMe"
    static let findGuestBooking = "/findGuestBooking"
    static let listGuestBookings = "/listGuestBookings"
    static let dcExec = "/dcExec"
}
