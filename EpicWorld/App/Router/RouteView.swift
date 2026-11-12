import SwiftUI

/// Builds the page for a stack entry — the `page:` column of the Dart route
/// table. Every page hides the system navigation bar and draws its own
/// Material `AppBar`, as the Flutter pages do.
struct RouteView: View {
    let entry: AppRouter.Entry

    var body: some View {
        page
            .toolbar(.hidden, for: .navigationBar)
            .environment(\.routeEntryID, entry.id)
    }

    @ViewBuilder
    private var page: some View {
        switch entry.route {
        // ---- Entry
        case .welcome(let onGetStarted): WelcomePage(onGetStarted: onGetStarted)
        case .mainShell: MainShellPage()
        // ---- Auth
        case .login(let popOnSuccess): LoginPage(popOnSuccess: popOnSuccess)
        case .signUp: SignUpPage()
        case .emailVerification(let userId, let email): EmailVerificationPage(userId: userId, email: email)
        case .twoStepVerification(let userId, let email): TwoStepVerificationPage(userId: userId, email: email)
        case .forgotPassword(let email): ForgotPasswordPage(email: email)
        case .resetPassword(let email): ResetPasswordPage(email: email)
        // ---- Home
        case .home: HomePage()
        case .commercialFlight: CommercialFlightPage()
        // ---- Booking flow
        case .searchResults: SearchResultsPage()
        case .bookingDetail: BookingDetailPage()
        case .payment: PaymentPage()
        case .paymentReturn: PaymentReturnPage()
        case .bookingCompleted(let ticket): BookingCompletedPage(ticket: ticket)
        case .locationPicker(let title, let exclude): LocationPickerPage(title: title, exclude: exclude)
        case .findMyBooking: FindMyBookingPage()
        case .flightSearchLoading(let from, let to): FlightSearchLoadingPage(from: from, to: to)
        // ---- Tickets
        case .tickets(let onBack): TicketsPage(onBack: onBack)
        case .history(let onBack): HistoryPage(onBack: onBack)
        case .ticketDetail(let ticket): TicketDetailPage(ticket: ticket)
        case .reservationDetail(let reservation): ReservationDetailPage(reservation: reservation)
        case .boardingPass(let ticket): BoardingPassPage(ticket: ticket)
        // ---- Catalogue
        case .hotel: HotelPage()
        case .hotelDetail(let category): HotelDetailPage(category: category)
        case .tour: TourPage()
        case .tourDetail(let tour): TourDetailPage(tour: tour)
        case .visa: VisaPage()
        case .visaCountry(let slug, let countryName, let flagUrl, let flagCode):
            VisaCountryPage(slug: slug, countryName: countryName, flagUrl: flagUrl, flagCode: flagCode)
        // ---- Member & profile
        case .member(let onBack): MemberPage(onBack: onBack)
        case .profile(let onBack): ProfilePage(onBack: onBack)
        case .manageProfile: ManageProfilePage()
        case .changePassword: ChangePasswordPage()
        case .language: LanguagePage()
        case .helpCenter: HelpCenterPage()
        case .about: AboutPage()
        // ---- Notifications
        case .notifications: NotificationsPage()
        case .notificationSettings: NotificationSettingsPage()
        }
    }
}
