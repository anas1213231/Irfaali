import SwiftUI
import UIKit

// UI-UPGRADE: Keep SwiftUI and native navigation chrome in the same language direction.
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
                guard let self, self.window != nil else { return }
                let attribute: UISemanticContentAttribute = self.isArabic ? .forceRightToLeft : .forceLeftToRight
                self.semanticContentAttribute = attribute
                // Scope to this hosting hierarchy, not global UIKit appearance or system pickers.
                var responder: UIResponder? = self
                while let current = responder, !(current is UIViewController) {
                    responder = current.next
                }
                guard var controller = responder as? UIViewController else { return }
                while let parent = controller.parent { controller = parent }
                self.updateNavigation(controller, attribute: attribute)
            }
        }

        private func updateNavigation(_ controller: UIViewController, attribute: UISemanticContentAttribute) {
            if let tabs = controller as? UITabBarController {
                tabs.tabBar.semanticContentAttribute = attribute
                tabs.tabBar.setNeedsLayout()
            }
            if let navigation = controller as? UINavigationController {
                navigation.navigationBar.semanticContentAttribute = attribute
                navigation.navigationBar.setNeedsLayout()
            }
            for child in controller.children {
                updateNavigation(child, attribute: attribute)
            }
        }
    }
}
