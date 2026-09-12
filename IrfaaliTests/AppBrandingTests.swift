import XCTest
@testable import Irfaali

final class AppBrandingTests: XCTestCase {
    func testOwnerMetadataMatchesProductionIdentity() {
        XCTAssertEqual(AppBranding.ownerHandle, "@ucorc")
        XCTAssertEqual(AppBranding.ownerLine, "Created & Owned by @ucorc")
        XCTAssertEqual(AppBranding.copyright, "© 2026 @ucorc. All Rights Reserved.")
    }

    func testTelegramURLIsCanonicalHTTPSDestination() throws {
        XCTAssertEqual(AppBranding.telegramURL.absoluteString, "https://t.me/ucorc")

        let components = try XCTUnwrap(
            URLComponents(url: AppBranding.telegramURL, resolvingAgainstBaseURL: false)
        )
        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "t.me")
        XCTAssertEqual(components.path, "/ucorc")
        XCTAssertNil(components.query)
        XCTAssertNil(components.fragment)
    }
}
