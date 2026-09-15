import SwiftUI
import UIKit

// Keep SwiftUI and native navigation chrome in the same language direction.
struct AppLanguageLayout: ViewModifier {
    @EnvironmentObject private var preferences: AppPreferences

    func body(content: Content) -> some View {
        content
            .environment(\.layoutDirection, preferences.layoutDirection)
            .environment(\.locale, preferences.locale)
            .background {
                NativeLanguageDirection(isArabic: preferences.isArabic)
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }
}

struct NativeLanguageDirection: UIViewRepresentable {
    let isArabic: Bool

    func makeUIView(context: Context) -> DirectionProbe {
        let view = DirectionProbe()
        view.isArabic = isArabic
        return view
    }

    func updateUIView(_ uiView: DirectionProbe, context: Context) {
        uiView.isArabic = isArabic
        uiView.scheduleUpdate()
    }

    final class DirectionProbe: UIView {
        var isArabic = false

        override func didMoveToWindow() {
            super.didMoveToWindow()
            scheduleUpdate()
        }

        func scheduleUpdate() {
            DispatchQueue.main.async { [weak self] in
                guard let self, let window = self.window else { return }
                let attribute: UISemanticContentAttribute = self.isArabic ? .forceRightToLeft : .forceLeftToRight

                // Apply the selected app language to this app window and its hosting hierarchy.
                // Updating only UINavigationBar/UITabBar can leave the English interface inheriting
                // a stale RTL direction after switching from Arabic.
                window.semanticContentAttribute = attribute
                window.setNeedsLayout()

                self.semanticContentAttribute = attribute

                var responder: UIResponder? = self
                while let current = responder, !(current is UIViewController) {
                    responder = current.next
                }
                guard var controller = responder as? UIViewController else { return }
                while let parent = controller.parent { controller = parent }

                self.updateControllerHierarchy(controller, attribute: attribute)
            }
        }

        private func updateControllerHierarchy(
            _ controller: UIViewController,
            attribute: UISemanticContentAttribute
        ) {
            controller.view.semanticContentAttribute = attribute
            controller.view.setNeedsLayout()

            if let tabs = controller as? UITabBarController {
                tabs.tabBar.semanticContentAttribute = attribute
                tabs.tabBar.setNeedsLayout()
            }

            if let navigation = controller as? UINavigationController {
                navigation.navigationBar.semanticContentAttribute = attribute
                navigation.navigationBar.setNeedsLayout()
                navigation.toolbar.semanticContentAttribute = attribute
                navigation.toolbar.setNeedsLayout()
            }

            for child in controller.children {
                updateControllerHierarchy(child, attribute: attribute)
            }
        }
    }
}
