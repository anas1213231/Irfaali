import SwiftUI
import SwiftData
import XCTest
@testable import Irfaali

final class InterfaceSnapshotTests: XCTestCase {
    @MainActor
    func testArabicStudioAndThemesLayout() async throws {
        let name = "Irfaali.Snapshots.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = AppPreferences(defaults: defaults)
        preferences.language = .arabic
        preferences.appearance = .dark
        preferences.animationsEnabled = false
        try await Self.capture(StudioView(), preferences: preferences, label: "studio")
        try await Self.capture(SettingsView(), preferences: preferences, label: "settings-dark")
        preferences.appearance = .light
        try await Self.capture(SettingsView(), preferences: preferences, label: "settings-light")
    }

    @MainActor
    static func capture<Content: View>(_ content: Content, preferences: AppPreferences, label: String) async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let original = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window.overrideUserInterfaceStyle = preferences.appearance == .light ? .light : .dark
        let root = NavigationStack { content }
            .environmentObject(preferences)
            .environment(\.layoutDirection, preferences.layoutDirection)
            .environment(\.locale, preferences.locale)
            .modelContainer(for: ProcessedVideoRecord.self, inMemory: true)
        let host = UIHostingController(rootView: root)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; original?.makeKeyAndVisible() }
        try await Task.sleep(for: .milliseconds(700))
        host.view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: window.bounds.size, format: format)
        let image = renderer.image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
        let data = try XCTUnwrap(image.jpegData(compressionQuality: 0.6))
        let attachment = XCTAttachment(image: image)
        attachment.name = label
        attachment.lifetime = .keepAlways
        XCTContext.runActivity(named: label) { $0.add(attachment) }
        // Synthetic empty-screen previews only; never capture user media.
        print("IRFAALI_PREVIEW_\(label):\(data.base64EncodedString())")
    }
}
