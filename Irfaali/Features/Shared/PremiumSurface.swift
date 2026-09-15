import SwiftUI

struct PremiumSurface<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(ObsidianGlass(cornerRadius: 18)) // UI-UPGRADE
            .shadow(color: shadowColor, radius: 8, y: 4)
    }

    private var shadowColor: Color {
        colorScheme == .dark ? .black.opacity(0.18) : .black.opacity(0.055)
    }
}

struct MetricTile: View {
    @Environment(\.colorScheme) private var colorScheme

    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.headline.weight(.semibold))
                .foregroundStyle(IrfaaliTheme.accent)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(IrfaaliTheme.silver)
            Text(value)
                .font(.system(.body, design: .default, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(ObsidianGlass(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(colorScheme == .dark ? .white.opacity(0.05) : .black.opacity(0.045), lineWidth: 0.5)
        }
    }
}
