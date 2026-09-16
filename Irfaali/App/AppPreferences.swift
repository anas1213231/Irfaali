import SwiftUI

@MainActor
final class AppPreferences: ObservableObject {
    enum Language: String, CaseIterable, Identifiable {
        case arabic
        case english

        var id: String { rawValue }
    }

    enum Appearance: String, CaseIterable, Identifiable {
        case dark
        case light

        var id: String { rawValue }
    }

    @Published var language: Language {
        didSet { defaults.set(language.rawValue, forKey: Keys.language) }
    }

    @Published var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    @Published var animationsEnabled: Bool {
        didSet { defaults.set(animationsEnabled, forKey: Keys.animationsEnabled) }
    }

    @Published var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.hapticsEnabled) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let rawLanguage = defaults.string(forKey: Keys.language),
           let savedLanguage = Language(rawValue: rawLanguage) {
            language = savedLanguage
        } else {
            language = Locale.current.language.languageCode?.identifier == "ar" ? .arabic : .english
        }

        if let rawAppearance = defaults.string(forKey: Keys.appearance) {
            switch rawAppearance {
            case Appearance.light.rawValue, "pureWhite":
                appearance = .light
            default:
                // Migrate legacy system / pureBlack / dark values to the two-theme model.
                appearance = .dark
            }
        } else {
            appearance = .dark
        }

        animationsEnabled = true
        hapticsEnabled = true
    }

    var isArabic: Bool { language == .arabic }
    var locale: Locale { Locale(identifier: isArabic ? "ar" : "en") }

    var layoutDirection: LayoutDirection {
        isArabic ? .rightToLeft : .leftToRight
    }

    var preferredColorScheme: ColorScheme? {
        appearance == .dark ? .dark : .light
    }

    func text(ar: String, en: String) -> String {
        isArabic ? ar : en
    }

    func appearanceName(_ value: Appearance) -> String {
        switch value {
        case .dark:
            text(ar: "داكن", en: "Dark")
        case .light:
            text(ar: "فاتح", en: "Light")
        }
    }

    private enum Keys {
        static let language = "app.language"
        static let appearance = "app.appearance"
        static let animationsEnabled = "app.animationsEnabled"
        static let hapticsEnabled = "app.hapticsEnabled"
    }
}
