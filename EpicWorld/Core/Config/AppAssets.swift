import Foundation

/// Every bundled asset path and remote brand-asset lookup — the port of
/// lib/core/config/app_assets.dart.
///
/// The strings are the Flutter paths verbatim. `AppImage` resolves them:
/// rasters from the bundled `assets/` folder reference, SVGs from the asset
/// catalog (image set named by file stem). Never write an asset name at a call
/// site — reference a constant here instead.
///
/// ```swift
/// AppImage(AppAssets.brandLogo, height: 36)   // Dart: Image.asset(AppAssets.brandLogo, height: 36)
/// AppImage(AppAssets.amenityWifi)             // Dart: SvgPicture.asset(AppAssets.amenityWifi)
/// ```
enum AppAssets {
    private static let images = "assets/images"
    private static let logos = "assets/images/logo"
    private static let icons = "assets/icons"

    // ---- Brand -------------------------------------------------------------
    /// Full wordmark used on the welcome page and auth headers.
    static let brandLogo = "\(images)/epic-world-logo.png"
    /// Wordmark reversed out for dark/green surfaces.
    static let brandLogoWhite = "\(images)/white2 logo.png"
    /// Square mark (also the launcher icon source).
    static let appLogo = "\(logos)/app_logo.png"
    static let appLogoTransparent = "\(logos)/logo_trans.png"
    static let googleLogo = "\(logos)/google-logo.png"
    static let logoMark = "\(images)/logo.png"
    /// IATA accreditation badge shown next to the wordmark.
    static let iataBadge = "\(images)/IATA.png"
    /// Sprites for the flight-search animation.
    static let logoGlobe = "\(images)/logo_globe.svg"
    static let logoPlane = "\(images)/logo_plane.svg"

    // ---- Imagery -----------------------------------------------------------
    static let loginBackground = "\(images)/login.webp"
    static let welcomeAirplane = "\(images)/h1-airplane.png"
    static let header = "\(images)/header.avif"
    static let wave = "\(logos)/wave.png"
    static let rewardBanner = "\(images)/reward.webp"
    static let profilePlaceholder = "\(images)/profile.jpg"
    static let versionTwoBanner = "\(images)/v2.png"
    static let visaHero = "\(images)/visa.svg"
    static let swapRoute = "\(images)/reverse.svg"
    static let hotelSample = "\(images)/c6.jpg"
    static let tourSample = "\(images)/b7.jpg"

    // ---- Payment -----------------------------------------------------------
    static let mmqr = "\(images)/MMQR.svg"
    static let mmqrCode = "\(images)/MMQR1.png"
    static let bankKbz = "\(logos)/kbz-logo.webp"
    static let bankAya = "\(logos)/AYA.jpg"
    static let bankCb = "\(logos)/cb.jpg"

    // ---- Department icons (home "Departments" block) -----------------------
    static let deptTicket = "\(icons)/dept_ticket.svg"
    static let deptTour = "\(icons)/dept_tour.svg"
    static let deptVisa = "\(icons)/dept_visa.svg"

    // ---- Contact-channel icons ---------------------------------------------
    static let channelCall = "\(icons)/ch_call.svg"
    static let channelViber = "\(icons)/ch_viber.svg"
    static let channelMessenger = "\(icons)/ch_messenger.svg"

    // ---- Hotel amenity icons -----------------------------------------------
    static let amenityAc = "\(icons)/amenity_ac.svg"
    static let amenityBar = "\(icons)/amenity_bar.svg"
    static let amenityBeach = "\(icons)/amenity_beach.svg"
    static let amenityBed = "\(icons)/amenity_bed.svg"
    static let amenityBedFamily = "\(icons)/amenity_bed_family.svg"
    static let amenityCafe = "\(icons)/amenity_cafe.svg"
    static let amenityCalendar = "\(icons)/amenity_calendar.svg"
    static let amenityChild = "\(icons)/amenity_child.svg"
    static let amenityCleaning = "\(icons)/amenity_cleaning.svg"
    static let amenityDesk = "\(icons)/amenity_desk.svg"
    static let amenityFitness = "\(icons)/amenity_fitness.svg"
    static let amenityGroups = "\(icons)/amenity_groups.svg"
    static let amenityKitchen = "\(icons)/amenity_kitchen.svg"
    static let amenityLaundry = "\(icons)/amenity_laundry.svg"
    static let amenityLocation = "\(icons)/amenity_location.svg"
    static let amenityLock = "\(icons)/amenity_lock.svg"
    static let amenityMeetingRoom = "\(icons)/amenity_meeting_room.svg"
    static let amenityMenu = "\(icons)/amenity_menu.svg"
    static let amenityParking = "\(icons)/amenity_parking.svg"
    static let amenityPool = "\(icons)/amenity_pool.svg"
    static let amenityReceipt = "\(icons)/amenity_receipt.svg"
    static let amenityRestaurant = "\(icons)/amenity_restaurant.svg"
    static let amenityRoomService = "\(icons)/amenity_room_service.svg"
    static let amenityShower = "\(icons)/amenity_shower.svg"
    static let amenityShuttle = "\(icons)/amenity_shuttle.svg"
    static let amenitySpa = "\(icons)/amenity_spa.svg"
    static let amenityWifi = "\(icons)/amenity_wifi.svg"

    // ---- Remote brand assets -----------------------------------------------
    /// Airline logo URL by IATA carrier code, with name aliases as a fallback.
    ///
    /// Search/schedule results normally carry a code, which lets every airline
    /// use the same CDN instead of requiring a new hard-coded name entry. Some
    /// legacy catalogue rows use a three-letter internal code (for example
    /// `MNA`), so well-known name aliases still resolve those records to the
    /// airline's two-character IATA code.
    static func airlineLogoUrl(_ operatorName: String, carrierCode: String? = nil) -> String {
        let suppliedCode = carrierCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
        let normalizedName = operatorName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
        let code: String
        if suppliedCode.range(of: "^[A-Z0-9]{2}$", options: .regularExpression) != nil {
            code = suppliedCode
        } else {
            switch normalizedName {
            case "maiairway", "mai", "myanmarairways", "myanmarairwaysinternational": code = "8M"
            case "mna", "myanmarnationalairlines": code = "UB"
            case "airkbz": code = "K7"
            case "airthanlwin": code = "HN"
            case "singaporeairlines": code = "SQ"
            case "thaiairways": code = "TG"
            case "airasia": code = "AK"
            default: code = ""
            }
        }
        return code.isEmpty ? "" : "https://pics.avs.io/60/60/\(code).png"
    }
}
