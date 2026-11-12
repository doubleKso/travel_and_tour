// Port of lib/features/promo/data/datasources/promo_mock_service.dart

import Foundation

/// In-memory stand-in for the promotions endpoint.
final class PromoMockService {
    init() {}

    /// Instance API used by `PromoRepositoryImpl`.
    func getPromos() -> [PromoModel] { Self.promos }

    /// Home-screen "Special Deals" carousel content.
    static let promos: [PromoModel] = [
        PromoModel(
            id: "p1",
            title: "Fly to Bangkok",
            subtitle: "International flights this rainy season",
            discountLabel: "Up to 30% OFF",
            imageUrl: "https://images.unsplash.com/photo-1556388158-158ea5ccacbd?w=900",
            partnerName: "MAI Airway",
            type: .flight
        ),
        PromoModel(
            id: "p2",
            title: "Yangon → Mandalay",
            subtitle: "Comfortable VIP express buses",
            discountLabel: "Flat 15% OFF",
            imageUrl: "https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?w=900",
            partnerName: "JJ Express",
            type: .bus
        ),
        PromoModel(
            id: "p3",
            title: "Domestic Getaways",
            subtitle: "Fly nationwide from just 49,000 MMK",
            discountLabel: "Weekend Deal",
            imageUrl: "https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=900",
            partnerName: "Air KBZ",
            type: .flight
        ),
        PromoModel(
            id: "p4",
            title: "Singapore Citybreak",
            subtitle: "Round-trip fares dropping this month",
            discountLabel: "Up to 25% OFF",
            imageUrl: "https://images.unsplash.com/photo-1525625293386-3f8f99389edd?w=900",
            partnerName: "Singapore Airlines",
            type: .flight
        ),
        PromoModel(
            id: "p5",
            title: "Highland Express",
            subtitle: "Overnight VIP buses to Taunggyi",
            discountLabel: "Flat 20% OFF",
            imageUrl: "https://images.unsplash.com/photo-1464219789935-c2d9d9aba644?w=900",
            partnerName: "Shwe Mandalar",
            type: .bus
        ),
    ]
}
