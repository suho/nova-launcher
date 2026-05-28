import SwiftUI

struct ErrorToast: View {
    let message: String
    let width: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var glassNamespace

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)

                Text(message)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(width: width, alignment: .center)
            .frame(minHeight: 54, alignment: .center)
            .glassEffect(toastGlass, in: toastShape)
            .glassEffectID("error-toast", in: glassNamespace)
            .background {
                toastShadowBacking
            }
            .overlay {
                toastSurfaceStroke
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var toastShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
    }

    private var toastGlass: Glass {
        .regular
            .tint(toastSurfaceTint)
            .interactive()
    }

    private var toastSurfaceTint: Color {
        colorScheme == .dark
            ? .black.opacity(0.04)
            : .white.opacity(0.02)
    }

    private var toastShadowBacking: some View {
        toastShape
            .fill(toastShadowFill)
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.14 : 0.13),
                radius: colorScheme == .dark ? 30 : 86,
                y: colorScheme == .dark ? 16 : 34
            )
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.09 : 0.10),
                radius: colorScheme == .dark ? 12 : 42,
                y: colorScheme == .dark ? 5 : 20
            )
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.06 : 0.055),
                radius: colorScheme == .dark ? 7 : 56,
                y: 0
            )
    }

    private var toastShadowFill: Color {
        .black.opacity(0.001)
    }

    private var toastSurfaceStroke: some View {
        toastShape
            .strokeBorder(toastStrokeGradient, lineWidth: colorScheme == .dark ? 0.5 : 1)
    }

    private var toastStrokeGradient: LinearGradient {
        let topColor = colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.white.opacity(0.30)
        let middleColor = colorScheme == .dark
            ? Color.white.opacity(0.05)
            : Color.white.opacity(0.12)
        let bottomColor = colorScheme == .dark
            ? Color.clear
            : Color.black.opacity(0.07)

        return LinearGradient(
            stops: [
                .init(color: topColor, location: 0),
                .init(color: middleColor, location: 0.56),
                .init(color: bottomColor, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
