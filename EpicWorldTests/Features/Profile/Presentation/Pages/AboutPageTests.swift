import XCTest
@testable import EpicWorld

/// Ports the logic assertion of
/// test/features/profile/presentation/pages/about_page_test.dart: the channel
/// labels follow the current language, because `socials()` is rebuilt on every
/// render instead of being cached in a static.
final class AboutPageTests: XCTestCase {
    // `common.phone` in each bundle.
    private let englishLabel = "Phone"
    private let myanmarLabel = "ဖုန်း"

    @MainActor
    func testTheAboutPageChannelLabelsFollowTheCurrentLanguage() {
        let originalCode = LocaleStore.shared.code
        let savedLocale = AppPrefs.getString("locale")
        let savedAppLocale = AppPrefs.getString(AppConsts.keyLocale)
        defer {
            L10n.change(originalCode)
            AppPrefs.setString("locale", savedLocale)
            AppPrefs.setString(AppConsts.keyLocale, savedAppLocale)
        }

        // Open in Myanmar first: a cached list would freeze these labels on
        // this very first read.
        L10n.change(L10n.myanmar)
        XCTAssertEqual(AboutPage.socials().first?.label, myanmarLabel)

        L10n.change(L10n.english)
        let labels = AboutPage.socials().map { $0.label }
        XCTAssertFalse(labels.contains(myanmarLabel))
        XCTAssertEqual(labels.first, englishLabel)
    }

    @MainActor
    func testEveryChannelHasAnAction() {
        let socials = AboutPage.socials()
        XCTAssertEqual(socials.count, 3)
        XCTAssertTrue(socials.allSatisfy { $0.action != nil })
        XCTAssertEqual(socials.map { $0.handle }, [AppConsts.officeMobile, AppConsts.officeMobile, AppConsts.messengerPage])
    }
}
