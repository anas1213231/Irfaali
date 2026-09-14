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
    func testLanguageSwitchUpdatesLiveInterfaceWithoutResettingState() async throws {
        let name = "Irfaali.LanguageLayout.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = AppPreferences(defaults: defaults)
        preferences.animationsEnabled = false
        preferences.language = .arabic
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let original = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        let state = LanguageLayoutObservation()
        let content = NavigationStack {
            LanguageLayoutProbe(observation: state)
                .modifier(AppLanguageLayout())
        }
        .environmentObject(preferences)
        // Deliberately conflicting inherited direction: the app preference must win.
        .environment(\.layoutDirection, .rightToLeft)
        let host = UIHostingController(rootView: content)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; original?.makeKeyAndVisible() }
        try await Task.sleep(for: .milliseconds(300))
        let identity = try XCTUnwrap(state.identity)
        XCTAssertEqual(state.direction, .rightToLeft)
        preferences.language = .english
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(state.direction, .leftToRight)
        XCTAssertEqual(state.localeIdentifier, "en")
        XCTAssertEqual(state.title, "Settings")
        XCTAssertEqual(state.identity, identity, "Switching language must preserve view state")
        let navigation = try XCTUnwrap(Self.navigationController(in: host))
        XCTAssertEqual(navigation.navigationBar.effectiveUserInterfaceLayoutDirection, .leftToRight)
        preferences.language = .arabic
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(state.direction, .rightToLeft)
        XCTAssertEqual(state.title, "الإعدادات")
        XCTAssertEqual(state.identity, identity)
        XCTAssertEqual(navigation.navigationBar.effectiveUserInterfaceLayoutDirection, .rightToLeft)
        preferences.language = .english
        try await Self.capture(SettingsView().modifier(AppLanguageLayout()), preferences: preferences, label: "settings-english")
    }

    @MainActor
    private static func navigationController(in controller: UIViewController) -> UINavigationController? {
        if let navigation = controller as? UINavigationController { return navigation }
        for child in controller.children {
            if let navigation = navigationController(in: child) { return navigation }
        }
        return nil
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


@MainActor
private final class LanguageLayoutObservation {
    var direction: LayoutDirection?
    var localeIdentifier = ""
    var title = ""
    var identity: UUID?
}

@MainActor
private struct LanguageLayoutProbe: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.layoutDirection) private var direction
    @Environment(\.locale) private var locale
    @State private var identity = UUID()
    let observation: LanguageLayoutObservation

    var body: some View {
        Text(preferences.text(ar: "الإعدادات", en: "Settings"))
            .onAppear { record() }
            .onChange(of: direction) { _, _ in record() }
            .onChange(of: locale.identifier) { _, _ in record() }
    }

    @MainActor
    private func record() {
        observation.direction = direction
        observation.localeIdentifier = locale.identifier
        observation.title = preferences.text(ar: "الإعدادات", en: "Settings")
        observation.identity = identity
    }
}
