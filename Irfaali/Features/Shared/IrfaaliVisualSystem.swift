import SwiftUI

enum IrfaaliVisual {
    static let electricCyan = Color(red: 0.30, green: 0.86, blue: 0.96)
    static let coolBlue = Color(red: 0.26, green: 0.48, blue: 0.84)
    static let deepViolet = Color(red: 0.34, green: 0.28, blue: 0.56)

    static let graphite = Color(white: 0.075)
    static let obsidian = Color(white: 0.025)
    static let quietFill = Color.white.opacity(0.040)
    static let quieterFill = Color.white.opacity(0.022)
    static let hairline = Color.white.opacity(0.105)
    static let strongHairline = Color.white.opacity(0.19)

    // Kept as shared compatibility tokens. The redesigned UI uses color as a signal,
    // not as a decorative surface treatment.
    static let energyGradient = LinearGradient(
        colors: [electricCyan, coolBlue],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let verticalEnergyGradient = LinearGradient(
        colors: [electricCyan, coolBlue],
        startPoint: .top,
        endPoint: .bottom
    )
}

struct IrfaaliBackdrop: View {
    var body: some View {
        ZStack {
            Color.black

            LinearGradient(
                colors: [
                    Color.white.opacity(0.020),
                    Color.white.opacity(0.006),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )

            Rectangle()
                .fill(IrfaaliVisual.graphite.opacity(0.22))
                .frame(height: 1)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 1)
        }
        .ignoresSafeArea()
    }
}

struct IrfaaliSectionHeading: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct IrfaaliHairline: View {
    var leadingInset: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(IrfaaliVisual.hairline)
            .frame(height: 0.5)
            .padding(.leading, leadingInset)
    }
}

struct IrfaaliMiniActivity: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var active = false

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                Rectangle()
                    .fill(index == 2 ? IrfaaliVisual.electricCyan : Color.white.opacity(0.48))
                    .frame(width: 1.5, height: active ? CGFloat(8 + ((index * 5) % 10)) : CGFloat(16 - ((index * 3) % 8)))
            }
        }
        .frame(width: 28, height: 24)
        .onAppear {
            guard preferences.animationsEnabled && !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.56).repeatForever(autoreverses: true)) {
                active = true
            }
        }
    }
}

/// Irfaali's processing signature: a video frame being reconstructed in time.
/// No spinner, orbit or decorative HUD; progress resolves displaced temporal slices
/// into one stable frame while a single scanning line travels through the image.
struct IrfaaliProcessingGlyph: View {
    let progress: Double

    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scanTravel: CGFloat = -44
    @State private var pulse = false

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 0.65)
                .frame(width: 178, height: 112)

            ZStack {
                ForEach(0..<9, id: \.self) { index in
                    let row = CGFloat(index) - 4
                    let unresolved = CGFloat(1 - clampedProgress)
                    let direction: CGFloat = index.isMultiple(of: 2) ? 1 : -1
                    let displacement = direction * unresolved * CGFloat(3 + ((index * 7) % 11))
                    let rowOpacity = 0.14 + (clampedProgress * 0.38)

                    Rectangle()
                        .fill(Color.white.opacity(rowOpacity))
                        .frame(width: 146 - abs(row) * 5, height: index == 4 ? 1.4 : 0.75)
                        .offset(x: displacement, y: row * 9.3)
                }

                Rectangle()
                    .fill(IrfaaliVisual.electricCyan.opacity(pulse ? 0.74 : 0.42))
                    .frame(width: 148, height: 1)
                    .offset(y: scanTravel)

                HStack(spacing: 4) {
                    ForEach(0..<13, id: \.self) { index in
                        Rectangle()
                            .fill(index <= Int(clampedProgress * 12) ? Color.white.opacity(0.46) : Color.white.opacity(0.10))
                            .frame(width: 6, height: 1)
                    }
                }
                .offset(y: 46)
            }
            .frame(width: 158, height: 92)
            .clipped()

            GeometryReader { proxy in
                let x = proxy.size.width * clampedProgress
                Rectangle()
                    .fill(IrfaaliVisual.electricCyan.opacity(0.85))
                    .frame(width: 1, height: 112)
                    .offset(x: max(0, min(proxy.size.width - 1, x)))
            }
            .frame(width: 178, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(width: 190, height: 124)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Processing")
        .onAppear {
            guard preferences.animationsEnabled && !reduceMotion else { return }

            withAnimation(.linear(duration: 2.35).repeatForever(autoreverses: false)) {
                scanTravel = 44
            }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

struct IrfaaliFooterSignature: View {
    var body: some View {
        Text("Designed by AI ✨")
            .font(.caption2.weight(.regular))
            .tracking(0.2)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
    }
}
