import SwiftUI

/// Semantic typography for the entire product.
///
/// The public repository intentionally does not contain the licensed Thmanyah
/// font binaries. All screens should depend on these semantic roles instead of
/// scattering concrete font names throughout the UI. When the licensed font
/// resources are added through the private/release path, only this mapping needs
/// to change.
enum IrfaaliTypography {
    static let brandDisplay = Font.system(size: 38, weight: .bold, design: .default)
    static let largeTitle = Font.system(size: 32, weight: .bold, design: .default)
    static let title = Font.system(size: 27, weight: .bold, design: .default)
    static let sectionTitle = Font.system(size: 20, weight: .semibold, design: .default)
    static let groupTitle = Font.system(size: 18, weight: .semibold, design: .default)
    static let body = Font.system(size: 17, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 17, weight: .medium, design: .default)
    static let secondaryBody = Font.system(size: 15, weight: .regular, design: .default)
    static let control = Font.system(size: 16, weight: .medium, design: .default)
    static let button = Font.system(size: 16, weight: .semibold, design: .default)
    static let metadata = Font.system(size: 13, weight: .medium, design: .default)
    static let metadataMonospaced = Font.system(size: 13, weight: .medium, design: .monospaced)
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    static let captionStrong = Font.system(size: 12, weight: .semibold, design: .default)

    /// PostScript names expected from the licensed Thmanyah package when it is
    /// embedded through the release/private resource path.
    enum Thmanyah {
        static let sansRegular = "ThmanyahSans-Regular"
        static let sansMedium = "ThmanyahSans-Medium"
        static let sansBold = "ThmanyahSans-Bold"
        static let serifTextRegular = "ThmanyahSerifText-Regular"
        static let serifDisplayMedium = "ThmanyahSerifDisplay-Medium"
        static let serifDisplayBold = "ThmanyahSerifDisplay-Bold"
    }
}
