// Port of lib/features/hotel/data/datasources/hotel_mock_service.dart
import Foundation

/// In-memory stand-in for the hotels/partners endpoint.
struct HotelMockService {
    init() {}

    /// Instance API used by `HotelRepositoryImpl`.
    func getHotels() -> [HotelModel] { Self.hotels }

    func getCategories() -> [HotelCategory] { Self.categories }

    /// Featured hotels for the home "Popular Hotels" section. In production these
    /// come from a partner/hotels endpoint; images are remote and cached.
    static let hotels: [HotelModel] = [
        HotelModel(
            id: "h1",
            name: "Sule Shangri-La",
            location: "Yangon, Myanmar",
            imageUrl:
                "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800",
            rating: 4.8,
            pricePerNight: 185000,
            currency: "MMK"
        ),
        HotelModel(
            id: "h2",
            name: "Mandalay Hill Resort",
            location: "Mandalay, Myanmar",
            imageUrl:
                "https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=800",
            rating: 4.6,
            pricePerNight: 142000,
            currency: "MMK"
        ),
        HotelModel(
            id: "h3",
            name: "The Peninsula",
            location: "Bangkok, Thailand",
            imageUrl:
                "https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?w=800",
            rating: 4.9,
            pricePerNight: 220000,
            currency: "MMK"
        ),
        HotelModel(
            id: "h4",
            name: "Marina Bay Sands",
            location: "Singapore",
            imageUrl:
                "https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?w=800",
            rating: 4.7,
            pricePerNight: 310000,
            currency: "MMK"
        ),
        HotelModel(
            id: "h5",
            name: "Inle Lake View",
            location: "Nyaung Shwe, Myanmar",
            imageUrl:
                "https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=800",
            rating: 4.5,
            pricePerNight: 98000,
            currency: "MMK"
        ),
    ]

    /// Every category shown on the Hotel screen.
    static let categories: [HotelCategory] = [
        business,
        family,
        corporate,
        student,
        luxury,
        budget,
    ]

    // -------------------------------------------------------------------------
    private static let business = HotelCategory(
        id: "business",
        title: "Business Hotels",
        tagline: "Convenient locations near business districts & meeting venues",
        imageUrl:
            "https://images.unsplash.com/photo-1590490360182-c33d57733427?w=1200",
        icon: Icons.business_center_rounded,
        overview:
            "Stay a few steps from the city's business districts. Our business "
            + "hotels pair fast Wi-Fi, quiet work-ready rooms and on-site meeting "
            + "spaces with easy access to offices, convention centres and transport "
            + "— so you can land, work and rest without missing a beat.",
        amenities: [
            HotelAmenity(AppAssets.amenityWifi, "Fast Wi-Fi"),
            HotelAmenity(AppAssets.amenityDesk, "Work desk"),
            HotelAmenity(AppAssets.amenityGroups, "Meeting rooms"),
            HotelAmenity(AppAssets.amenityCafe, "Café & bar"),
            HotelAmenity(AppAssets.amenityFitness, "Fitness centre"),
            HotelAmenity(AppAssets.amenityParking, "Parking"),
        ],
        features: [
            "Prime downtown & business-district locations",
            "High-speed Wi-Fi in every room",
            "On-site meeting & conference rooms",
            "Express check-in / check-out",
            "24-hour business centre",
        ],
        idealFor: [
            "Business travellers & executives",
            "Conference & meeting trips",
            "Short work stays",
        ],
        gallery: [
            "https://images.unsplash.com/photo-1590490360182-c33d57733427?w=600",
            "https://images.unsplash.com/photo-1618773928121-c32242e63f39?w=600",
            "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=600",
        ],
        priceFrom: 85000,
        currency: "MMK"
    )

    // -------------------------------------------------------------------------
    private static let family = HotelCategory(
        id: "family",
        title: "Family-Friendly Hotels",
        tagline: "Spacious rooms, safe environments, kid-friendly facilities",
        imageUrl:
            "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=1200",
        icon: Icons.family_restroom_rounded,
        overview:
            "Room to relax together. Family-friendly hotels offer spacious rooms, "
            + "connecting options and safe, welcoming spaces for children — plus pools, "
            + "play areas and family dining so everyone travels happy.",
        amenities: [
            HotelAmenity(AppAssets.amenityBedFamily, "Family rooms"),
            HotelAmenity(AppAssets.amenityPool, "Swimming pool"),
            HotelAmenity(AppAssets.amenityChild, "Kids facilities"),
            HotelAmenity(AppAssets.amenityRestaurant, "Family dining"),
            HotelAmenity(AppAssets.amenityWifi, "Free Wi-Fi"),
            HotelAmenity(AppAssets.amenityParking, "Parking"),
        ],
        features: [
            "Spacious & connecting family rooms",
            "Safe, child-friendly environments",
            "Kids play areas & pools",
            "Cots & extra beds on request",
            "Family meal options",
        ],
        idealFor: [
            "Families with children",
            "Multi-generation trips",
            "Relaxed holiday stays",
        ],
        gallery: [
            "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=600",
            "https://images.unsplash.com/photo-1445019980597-93fa8acb246c?w=600",
            "https://images.unsplash.com/photo-1455587734955-081b22074882?w=600",
        ],
        priceFrom: 95000,
        currency: "MMK"
    )

    // -------------------------------------------------------------------------
    private static let corporate = HotelCategory(
        id: "corporate",
        title: "Corporate Stays",
        tagline: "For groups, conferences, and company trips",
        imageUrl:
            "https://images.unsplash.com/photo-1618773928121-c32242e63f39?w=1200",
        icon: Icons.corporate_fare_rounded,
        overview:
            "Built for teams. Corporate stays make group travel effortless with "
            + "block bookings, event and conference facilities, and consolidated "
            + "billing — so your whole company arrives, meets and stays together "
            + "with one point of contact.",
        amenities: [
            HotelAmenity(AppAssets.amenityMeetingRoom, "Event halls"),
            HotelAmenity(AppAssets.amenityGroups, "Group rates"),
            HotelAmenity(AppAssets.amenityReceipt, "One invoice"),
            HotelAmenity(AppAssets.amenityWifi, "Fast Wi-Fi"),
            HotelAmenity(AppAssets.amenityShuttle, "Group transfers"),
            HotelAmenity(AppAssets.amenityRestaurant, "Catering"),
        ],
        features: [
            "Block bookings for groups",
            "Conference & event facilities",
            "Consolidated corporate billing",
            "Dedicated coordinator",
            "Group airport transfers",
        ],
        idealFor: [
            "Company trips & retreats",
            "Conferences & seminars",
            "Large travelling groups",
        ],
        gallery: [
            "https://images.unsplash.com/photo-1618773928121-c32242e63f39?w=600",
            "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=600",
            "https://images.unsplash.com/photo-1590490360182-c33d57733427?w=600",
        ],
        priceFrom: 80000,
        currency: "MMK"
    )

    // -------------------------------------------------------------------------
    private static let student = HotelCategory(
        id: "student",
        title: "Student / Long Stay Options",
        tagline: "Affordable, comfortable, and practical for long-term stays",
        imageUrl:
            "https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=1200",
        icon: Icons.school_rounded,
        overview:
            "Made for the long haul. Long-stay options offer discounted weekly and "
            + "monthly rates, in-room kitchenettes and laundry, and practical, "
            + "comfortable rooms — perfect for students, interns and anyone settling "
            + "in for an extended stay.",
        amenities: [
            HotelAmenity(AppAssets.amenityKitchen, "Kitchenette"),
            HotelAmenity(AppAssets.amenityLaundry, "Laundry"),
            HotelAmenity(AppAssets.amenityCalendar, "Monthly rates"),
            HotelAmenity(AppAssets.amenityWifi, "Free Wi-Fi"),
            HotelAmenity(AppAssets.amenityDesk, "Study desk"),
            HotelAmenity(AppAssets.amenityCleaning, "Housekeeping"),
        ],
        features: [
            "Discounted weekly & monthly rates",
            "In-room kitchenette & laundry",
            "Comfortable, practical rooms",
            "Flexible check-in dates",
            "Quiet study-friendly spaces",
        ],
        idealFor: [
            "Students & interns",
            "Long-term relocations",
            "Extended work assignments",
        ],
        gallery: [
            "https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=600",
            "https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=600",
            "https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=600",
        ],
        priceFrom: 45000,
        currency: "MMK"
    )

    // -------------------------------------------------------------------------
    private static let luxury = HotelCategory(
        id: "luxury",
        title: "Luxury Hotels & Resorts",
        tagline: "4-star & 5-star hotels with premium facilities",
        imageUrl:
            "https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=1200",
        icon: Icons.star_rounded,
        overview:
            "Travel in style. Our 4- and 5-star hotels and resorts deliver premium "
            + "rooms, spas and infinity pools, fine dining and attentive service — "
            + "the ultimate stay for special occasions and unforgettable escapes.",
        amenities: [
            HotelAmenity(AppAssets.amenityPool, "Infinity pool"),
            HotelAmenity(AppAssets.amenitySpa, "Spa & wellness"),
            HotelAmenity(AppAssets.amenityMenu, "Fine dining"),
            HotelAmenity(AppAssets.amenityRoomService, "Room service"),
            HotelAmenity(AppAssets.amenityBeach, "Beach access"),
            HotelAmenity(AppAssets.amenityBar, "Lounge & bar"),
        ],
        features: [
            "Premium 4-star & 5-star properties",
            "Spa, wellness & infinity pools",
            "Fine-dining restaurants",
            "24-hour concierge & room service",
            "Sea-view & suite upgrades",
        ],
        idealFor: [
            "Honeymoons & anniversaries",
            "Luxury getaways",
            "Special celebrations",
        ],
        gallery: [
            "https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=600",
            "https://images.unsplash.com/photo-1455587734955-081b22074882?w=600",
            "https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=600",
        ],
        priceFrom: 220000,
        currency: "MMK"
    )

    // -------------------------------------------------------------------------
    private static let budget = HotelCategory(
        id: "budget",
        title: "Budget Hotels & Guesthouses",
        tagline: "Clean, safe, and affordable options",
        imageUrl:
            "https://images.unsplash.com/photo-1555854877-bab0e564b8d5?w=1200",
        icon: Icons.luggage_rounded,
        overview:
            "Great value, no compromise on the essentials. Budget hotels and "
            + "guesthouses offer clean, safe and comfortable rooms in handy "
            + "locations — the smart choice for travellers who'd rather spend on "
            + "the trip than the room.",
        amenities: [
            HotelAmenity(AppAssets.amenityBed, "Clean rooms"),
            HotelAmenity(AppAssets.amenityWifi, "Free Wi-Fi"),
            HotelAmenity(AppAssets.amenityShower, "Private bathroom"),
            HotelAmenity(AppAssets.amenityAc, "Air-con"),
            HotelAmenity(AppAssets.amenityLock, "Secure & safe"),
            HotelAmenity(AppAssets.amenityLocation, "Central spots"),
        ],
        features: [
            "Clean, safe & affordable rooms",
            "Handy central locations",
            "Friendly local hosts",
            "Free Wi-Fi & essentials",
            "Great value nightly rates",
        ],
        idealFor: [
            "Backpackers & solo travellers",
            "Short city breaks",
            "Value-focused trips",
        ],
        gallery: [
            "https://images.unsplash.com/photo-1555854877-bab0e564b8d5?w=600",
            "https://images.unsplash.com/photo-1568495248636-6432b97bd949?w=600",
            "https://images.unsplash.com/photo-1611048267451-e6ed903d4a38?w=600",
        ],
        priceFrom: 30000,
        currency: "MMK"
    )
}
