import SwiftUI
import UIKit

// Keep SwiftUI and native UIKit chrome in the same language direction.
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

                let attribute: UISemanticContentAttribute = self.isArabic
                    ? .forceRightToLeft
                    : .forceLeftToRight

                // The selected in-app language owns the direction of the whole app window.
                // This prevents English from inheriting stale RTL semantics after a live
                // Arabic -> English switch, including native navigation, tabs and sheets.
                window.semanticContentAttribute = attribute
                window.setNeedsLayout()
                window.layoutIfNeeded()

                self.semanticContentAttribute = attribute

                if let root = window.rootViewController {
                    self.updateControllerHierarchy(root, attribute: attribute)
                }
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

            if let presented = controller.presentedViewController {
                updateControllerHierarchy(presented, attribute: attribute)
            }
        }
    }
}
