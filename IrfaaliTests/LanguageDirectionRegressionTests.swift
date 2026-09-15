import SwiftUI
import XCTest
@testable import Irfaali

final class LanguageDirectionRegressionTests: XCTestCase {
    @MainActor
    func testEnglishSwitchForcesHostingWindowLeftToRightWithoutRebuildingState() async throws {
        let suite = "Irfaali.LanguageDirectionRegression.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let preferences = AppPreferences(defaults: defaults)
        preferences.animationsEnabled = false
        preferences.language = .arabic

        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first
        )
        let originalWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)

        let observation = DirectionObservation()
        let content = NavigationStack {
            DirectionProbe(observation: observation)
                .modifier(AppLanguageLayout())
        }
        .environmentObject(preferences)
        // Reproduce the stale inherited RTL state that affected English in production.
        .environment(\.layoutDirection, .rightToLeft)

        let host = UIHostingController(rootView: content)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            originalWindow?.makeKeyAndVisible()
        }

        try await Task.sleep(for: .milliseconds(300))
        let identity = try XCTUnwrap(observation.identity)
        XCTAssertEqual(observation.direction, .rightToLeft)

        preferences.language = .english
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(observation.direction, .leftToRight)
        XCTAssertEqual(observation.identity, identity, "Language switching must preserve SwiftUI view state")
        XCTAssertEqual(window.effectiveUserInterfaceLayoutDirection, .leftToRight)
        XCTAssertEqual(host.view.effectiveUserInterfaceLayoutDirection, .leftToRight)
    }
}

@MainActor
private final class DirectionObservation {
    var direction: LayoutDirection?
    var identity: UUID?
}

@MainActor
private struct DirectionProbe: View {
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var identity = UUID()
    let observation: DirectionObservation

    var body: some View {
        Text("direction")
            .onAppear { record() }
            .onChange(of: layoutDirection) { _, _ in record() }
    }

    private func record() {
        observation.direction = layoutDirection
        observation.identity = identity
    }
}
