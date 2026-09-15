import XCTest
@testable import Irfaali

@MainActor
final class AppPreferencesTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "IrfaaliTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testLanguagePersistsAndUpdatesLayoutDirection() {
        let preferences = AppPreferences(defaults: defaults)
        preferences.language = .arabic

        XCTAssertTrue(preferences.isArabic)
        XCTAssertEqual(preferences.layoutDirection, .rightToLeft)

        let reloaded = AppPreferences(defaults: defaults)
        XCTAssertEqual(reloaded.language, .arabic)
        XCTAssertEqual(reloaded.layoutDirection, .rightToLeft)
    }

    func testEnglishUsesLeftToRightLayout() {
        let preferences = AppPreferences(defaults: defaults)
        preferences.language = .english

        XCTAssertFalse(preferences.isArabic)
        XCTAssertEqual(preferences.layoutDirection, .leftToRight)
        XCTAssertEqual(preferences.text(ar: "عربي", en: "English"), "English")
    }

    func testAppearancePersists() {
        let preferences = AppPreferences(defaults: defaults)
        preferences.appearance = .pureBlack

        let reloaded = AppPreferences(defaults: defaults)
        XCTAssertEqual(reloaded.appearance, .dark)
        XCTAssertEqual(reloaded.preferredColorScheme, .dark)
    }

    func testMotionAndHapticsStayEnabledWithoutUserSettings() {
        let preferences = AppPreferences(defaults: defaults)
        preferences.animationsEnabled = false
        preferences.hapticsEnabled = false

        let reloaded = AppPreferences(defaults: defaults)
        XCTAssertTrue(reloaded.animationsEnabled)
        XCTAssertTrue(reloaded.hapticsEnabled)
    }
}
