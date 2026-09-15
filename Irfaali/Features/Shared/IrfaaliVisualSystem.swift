import SwiftUI

enum IrfaaliVisual {
    static let electricCyan = Color(red: 0.25, green: 0.86, blue: 0.98)
    static let coolBlue = Color(red: 0.20, green: 0.48, blue: 0.92)
    static let deepViolet = Color(red: 0.38, green: 0.26, blue: 0.72)
    static let quietFill = Color.white.opacity(0.045)
    static let quieterFill = Color.white.opacity(0.026)
    static let hairline = Color.white.opacity(0.105)
    static let strongHairline = Color.white.opacity(0.18)

    static let energyGradient = LinearGradient(
        colors: [electricCyan, coolBlue, deepViolet],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let verticalEnergyGradient = LinearGradient(
        colors: [electricCyan, coolBlue, deepViolet],
        startPoint: .top,
        endPoint: .bottom
    )
}

struct IrfaaliBackdrop: View {
    var body: some View {
        ZStack {
            Color.black

            RadialGradient(
                colors: [
                    IrfaaliVisual.coolBlue.opacity(0.085),
                    IrfaaliVisual.deepViolet.opacity(0.026),
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 430
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.018),
                    .clear,
                    Color.black.opacity(0.16)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
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
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.subheadline)
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
        HStack(alignment: .center, spacing: 4) {
            Capsule()
                .frame(width: 3, height: active ? 14 : 7)
            Capsule()
                .frame(width: 3, height: active ? 8 : 16)
            Capsule()
                .frame(width: 3, height: active ? 16 : 9)
            Capsule()
                .frame(width: 3, height: active ? 10 : 13)
        }
        .foregroundStyle(IrfaaliVisual.energyGradient)
        .frame(width: 34, height: 28)
        .onAppear {
            guard preferences.animationsEnabled && !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.62).repeatForever(autoreverses: true)) {
                active = true
            }
        }
    }
}

struct IrfaaliProcessingGlyph: View {
    let progress: Double

    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var outerRotation = 0.0
    @State private var middleRotation = 0.0
    @State private var innerRotation = 0.0
    @State private var breathing = false

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.055), lineWidth: 1)
                .frame(width: 184, height: 184)

            Circle()
                .trim(from: 0.04, to: 0.67)
                .stroke(
                    AngularGradient(
                        colors: [
                            IrfaaliVisual.electricCyan.opacity(0.22),
                            IrfaaliVisual.electricCyan,
                            IrfaaliVisual.coolBlue,
                            IrfaaliVisual.deepViolet.opacity(0.76),
                            .clear
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 2.1, lineCap: .round)
                )
                .frame(width: 174, height: 174)
                .rotationEffect(.degrees(outerRotation))

            Circle()
                .trim(from: 0.18, to: 0.86)
                .stroke(
                    AngularGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.18),
                            IrfaaliVisual.coolBlue.opacity(0.74),
                            .clear
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 1.15, lineCap: .round)
                )
                .frame(width: 132, height: 132)
                .rotationEffect(.degrees(middleRotation))

            Circle()
                .trim(from: 0.08, to: 0.52)
                .stroke(
                    IrfaaliVisual.energyGradient,
                    style: StrokeStyle(lineWidth: 1.55, lineCap: .round)
                )
                .frame(width: 96, height: 96)
                .rotationEffect(.degrees(innerRotation))

            Circle()
                .fill(IrfaaliVisual.electricCyan)
                .frame(width: 5, height: 5)
                .shadow(color: IrfaaliVisual.electricCyan.opacity(0.45), radius: 5)
                .offset(y: -87)
                .rotationEffect(.degrees(outerRotation))

            Circle()
                .fill(IrfaaliVisual.coolBlue.opacity(0.95))
                .frame(width: 4, height: 4)
                .offset(y: -66)
                .rotationEffect(.degrees(middleRotation + 120))

            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.black.opacity(0.88))
                    .frame(width: 66, height: 48)

                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .trim(from: 0, to: max(0.035, clampedProgress))
                    .stroke(
                        IrfaaliVisual.energyGradient,
                        style: StrokeStyle(lineWidth: 1.7, lineCap: .round)
                    )
                    .frame(width: 66, height: 48)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.clear, IrfaaliVisual.electricCyan.opacity(0.86), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 42, height: 1.2)
                    .offset(y: CGFloat(clampedProgress - 0.5) * 28)

                Circle()
                    .fill(Color.white)
                    .frame(width: 5, height: 5)
                    .shadow(color: IrfaaliVisual.electricCyan.opacity(0.55), radius: 7)
            }
            .scaleEffect(breathing ? 1.035 : 0.99)
        }
        .frame(width: 196, height: 196)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Processing")
        .onAppear {
            guard preferences.animationsEnabled && !reduceMotion else { return }

            withAnimation(.linear(duration: 8.6).repeatForever(autoreverses: false)) {
                outerRotation = 360
            }
            withAnimation(.linear(duration: 5.4).repeatForever(autoreverses: false)) {
                middleRotation = -360
            }
            withAnimation(.linear(duration: 3.8).repeatForever(autoreverses: false)) {
                innerRotation = 360
            }
            withAnimation(.easeInOut(duration: 1.45).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }
}

struct IrfaaliFooterSignature: View {
    var body: some View {
        Text("Designed by AI ✨")
            .font(.caption2.weight(.medium))
            .tracking(0.4)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
    }
}
