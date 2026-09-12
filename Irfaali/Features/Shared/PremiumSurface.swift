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
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(borderColor, lineWidth: 0.8)
            }
            .shadow(color: shadowColor, radius: colorScheme == .dark ? 22 : 14, y: colorScheme == .dark ? 13 : 8)
    }

    private var borderColor: Color {
        colorScheme == .dark ? .white.opacity(0.11) : .black.opacity(0.075)
    }

    private var shadowColor: Color {
        colorScheme == .dark ? .black.opacity(0.28) : .black.opacity(0.09)
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
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .default, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tileFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(colorScheme == .dark ? .white.opacity(0.055) : .black.opacity(0.05), lineWidth: 0.7)
        }
    }

    private var tileFill: Color {
        colorScheme == .dark ? .white.opacity(0.052) : .white.opacity(0.68)
    }
}
