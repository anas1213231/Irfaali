import SwiftUI

struct PremiumSurface<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(ObsidianGlass(cornerRadius: 18)) // UI-UPGRADE
            .shadow(color: shadowColor, radius: 12, y: 6)
    }

    private var borderColor: Color {
        colorScheme == .dark ? .white.opacity(0.095) : .black.opacity(0.065)
    }

    private var shadowColor: Color {
        colorScheme == .dark ? .black.opacity(0.22) : .black.opacity(0.07)
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
                .stroke(colorScheme == .dark ? .white.opacity(0.055) : .black.opacity(0.05), lineWidth: 0.5)
        }
    }

    private var tileFill: Color {
        colorScheme == .dark ? .white.opacity(0.052) : .white.opacity(0.68)
    }
}
