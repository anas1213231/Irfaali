import SwiftUI

@MainActor
final class AppPreferences: ObservableObject {
    enum Language: String, CaseIterable, Identifiable {
        case arabic
        case english

        var id: String { rawValue }
    }

    enum Appearance: String, CaseIterable, Identifiable {
        case system
        case pureBlack
        case dark
        case light
        case pureWhite

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

        if let rawAppearance = defaults.string(forKey: Keys.appearance),
           let savedAppearance = Appearance(rawValue: rawAppearance) {
            appearance = savedAppearance
        } else {
            appearance = .system
        }

        animationsEnabled = defaults.object(forKey: Keys.animationsEnabled) as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: Keys.hapticsEnabled) as? Bool ?? true
    }

    var isArabic: Bool { language == .arabic }
    var locale: Locale { Locale(identifier: isArabic ? "ar" : "en") }

    var layoutDirection: LayoutDirection {
        isArabic ? .rightToLeft : .leftToRight
    }

    var preferredColorScheme: ColorScheme? {
        switch appearance {
        case .system:
            nil
        case .pureBlack, .dark:
            .dark
        case .light, .pureWhite:
            .light
        }
    }

    func text(ar: String, en: String) -> String {
        isArabic ? ar : en
    }

    func appearanceName(_ value: Appearance) -> String {
        switch value {
        case .system:
            text(ar: "حسب الآيفون", en: "System")
        case .pureBlack:
            text(ar: "أسود فخم", en: "Pure Black")
        case .dark:
            text(ar: "داكن", en: "Dark")
        case .light:
            text(ar: "فاتح", en: "Light")
        case .pureWhite:
            text(ar: "أبيض نقي", en: "Pure White")
        }
    }

    private enum Keys {
        static let language = "app.language"
        static let appearance = "app.appearance"
        static let animationsEnabled = "app.animationsEnabled"
        static let hapticsEnabled = "app.hapticsEnabled"
    }
}
