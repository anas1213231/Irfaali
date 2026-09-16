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
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(surfaceFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(surfaceStroke, lineWidth: 0.5)
            }
    }

    private var surfaceFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.040)
            : Color.black.opacity(0.032)
    }

    private var surfaceStroke: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color.white.opacity(0.14), Color.white.opacity(0.055), Color.white.opacity(0.025)]
                : [Color.black.opacity(0.11), Color.black.opacity(0.045), Color.black.opacity(0.020)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct MetricTile: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.body, design: .default, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}
