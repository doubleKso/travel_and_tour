import XCTest
@testable import EpicWorld

/// Ports test/core/utils/*, test/core/config/app_assets_test.dart and
/// test/app/config/flavor_endpoint_test.dart.
final class AccessTokenTests: XCTestCase {
    private let now = DateTime.utc(2026, 9, 1, 12)

    /// An unsigned JWT whose payload carries `claims`.
    private func jwt(_ claims: [String: Any]) -> String {
        func segment(_ value: [String: Any]) -> String {
            let data = try! JSONSerialization.data(withJSONObject: value)
            return data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        return "\(segment(["alg": "HS256", "typ": "JWT"])).\(segment(claims)).signature"
    }

    private func expiringAt(_ moment: DateTime) -> String {
        jwt(["sub": "user-1", "exp": moment.millisecondsSinceEpoch / 1000])
    }

    func testReadsExpClaim() {
        let expiry = now.add(Duration(hours: 1))
        XCTAssertEqual(AccessToken.expiryOf(expiringAt(expiry)), expiry)
    }

    func testTokenGoodForAnotherHourIsUsedAsIs() {
        XCTAssertFalse(AccessToken.needsRefresh(expiringAt(now.add(Duration(hours: 1))), now: now))
    }

    func testExpiredTokenIsRefreshed() {
        XCTAssertTrue(AccessToken.needsRefresh(expiringAt(now.subtract(Duration(minutes: 1))), now: now))
    }

    func testTokenInsideLeewayIsRefreshed() {
        let token = expiringAt(now.add(Duration(seconds: 30)))
        XCTAssertTrue(AccessToken.needsRefresh(token, now: now))
        XCTAssertFalse(AccessToken.needsRefresh(token, leeway: .zero, now: now))
    }

    func testUnreadableTokenCountsAsStale() {
        for token in ["", "   ", "opaque-session-token", "a.b", "a.!!.c"] {
            XCTAssertTrue(AccessToken.needsRefresh(token, now: now), "expected \"\(token)\" to be refreshed")
            XCTAssertNil(AccessToken.expiryOf(token))
        }
    }

    func testTokenWithoutUsableExpCountsAsStale() {
        XCTAssertNil(AccessToken.expiryOf(jwt(["sub": "user-1"])))
        XCTAssertNil(AccessToken.expiryOf(jwt(["exp": 0])))
        XCTAssertTrue(AccessToken.needsRefresh(jwt(["sub": "user-1"]), now: now))
    }

    func testExpAsStringIsUnderstood() {
        let expiry = now.add(Duration(hours: 2))
        let token = jwt(["exp": "\(expiry.millisecondsSinceEpoch / 1000)"])
        XCTAssertEqual(AccessToken.expiryOf(token), expiry)
        XCTAssertFalse(AccessToken.needsRefresh(token, now: now))
    }
}

final class FormattersTests: XCTestCase {
    func testScheduleTimesGetAnAmPmPeriod() {
        XCTAssertEqual(Formatters.scheduleTime12("08:30"), "08:30 am")
        XCTAssertEqual(Formatters.scheduleTime12("14:05"), "02:05 pm")
        XCTAssertEqual(Formatters.scheduleTime12("7:00 PM"), "07:00 pm")
    }

    func testETicketTimesHaveExplicitSuffix() {
        XCTAssertEqual(Formatters.eTicketTime(DateTime(2026, 9, 17, 0, 5)), "12:05 A.M.")
        XCTAssertEqual(Formatters.eTicketTime(DateTime(2026, 9, 17, 12, 5)), "12:05 P.M.")
        XCTAssertEqual(Formatters.eTicketTime(DateTime(2026, 9, 17, 19, 45)), "7:45 P.M.")
    }

    func testUnknownScheduleFormatsArePreserved() {
        XCTAssertEqual(Formatters.scheduleTime12("On request"), "On request")
        XCTAssertEqual(Formatters.scheduleTime12(""), "")
    }

    func testPriceIsGroupedWithCurrency() {
        XCTAssertEqual(Formatters.price(505000, "MMK"), "505,000 MMK")
    }

    func testDatesRenderInEnglishWhateverTheLanguage() {
        let date = DateTime(2026, 6, 12)
        XCTAssertEqual(Formatters.shortDate(date), "Fri, 12 Jun")
        XCTAssertEqual(Formatters.fullDate(date), "12 Jun 2026")
        XCTAssertEqual(Formatters.numericDate(date), "12/06/2026")
        XCTAssertEqual(Formatters.numericDateShort(date), "12/06/26")
        XCTAssertEqual(Formatters.monthYear(date), "June 2026")
    }

    func testTryParseDateAcceptsTheDisplayedAndNumericForms() {
        XCTAssertEqual(Formatters.tryParseDate("12 Jun 2026"), DateTime(2026, 6, 12))
        XCTAssertEqual(Formatters.tryParseDate("12/6/2026"), DateTime(2026, 6, 12))
        XCTAssertEqual(Formatters.tryParseDate("2026-6-12"), DateTime(2026, 6, 12))
        XCTAssertNil(Formatters.tryParseDate("not a date"))
    }

    func testDurationAndCountdown() {
        XCTAssertEqual(Formatters.duration(Duration(hours: 1, minutes: 25)), "1h 25m")
        XCTAssertEqual(Formatters.duration(Duration(minutes: 40)), "40m")
        XCTAssertEqual(Formatters.countdown(Duration(days: 2, hours: 4, minutes: 12)), "2d 4h 12m")
        XCTAssertEqual(Formatters.countdown(Duration(minutes: -1)), "Departed")
    }
}

final class AppAssetsTests: XCTestCase {
    func testLegacyMnaRecordsResolveToUbLogo() {
        XCTAssertEqual(
            AppAssets.airlineLogoUrl("Myanmar National Airlines", carrierCode: "MNA"),
            "https://pics.avs.io/60/60/UB.png"
        )
    }

    func testAnyTwoCharacterCodeResolvesWithoutNameMapping() {
        XCTAssertEqual(
            AppAssets.airlineLogoUrl("Unknown airline", carrierCode: "vz"),
            "https://pics.avs.io/60/60/VZ.png"
        )
    }
}

final class FlavorEndpointTests: XCTestCase {
    func testProductionCallablesResolveToConfiguredFunctionsUrl() {
        F.appFlavor = .prod
        XCTAssertEqual(Endpoints.searchFlights, "/searchFlights")
        XCTAssertEqual(
            F.functionsUrl(Endpoints.searchFlights),
            "https://asia-southeast1-epicworld-fad26.cloudfunctions.net/searchFlights"
        )
        XCTAssertEqual(
            F.functionsUrl(Endpoints.holdFlight),
            "https://asia-southeast1-epicworld-fad26.cloudfunctions.net/holdFlight"
        )
        XCTAssertEqual(
            F.functionsUrl(Endpoints.confirmTicketing),
            "https://asia-southeast1-epicworld-fad26.cloudfunctions.net/confirmTicketing"
        )
    }
}

final class ContactLauncherTests: XCTestCase {
    func testViberUriUsesDialableNumber() {
        XCTAssertEqual(
            ContactLauncher.viberChatUri("+95 9 4500 12345")?.absoluteString,
            "viber://chat?number=%2B959450012345"
        )
    }

    func testMessengerUriTargetsPublicPage() {
        XCTAssertEqual(ContactLauncher.messengerUri("epicworldtravel")?.absoluteString, "https://m.me/epicworldtravel")
    }

    func testToDialableStripsDecoration() {
        XCTAssertEqual(ContactLauncher.toDialable("+95 9 787 844 882"), "+959787844882")
    }
}
