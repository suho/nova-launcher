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
        .clear
            .interactive()
    }

    private var toastShadowBacking: some View {
        toastShape
            .fill(.black.opacity(0.001))
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.14 : 0.13),
                radius: colorScheme == .dark ? 30 : 86,
                y: colorScheme == .dark ? 16 : 34
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.09 : 0.10), radius: 12, y: 5)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.06 : 0.055), radius: 7, y: 0)
    }

    private var toastSurfaceStroke: some View {
        toastShape
            .strokeBorder(toastStrokeGradient, lineWidth: colorScheme == .dark ? 0.5 : 1)
    }

    private var toastStrokeGradient: LinearGradient {
        let topColor = colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.11)
        let middleColor = colorScheme == .dark
            ? Color.white.opacity(0.05)
            : Color.black.opacity(0.06)

        return LinearGradient(
            stops: [
                .init(color: topColor, location: 0),
                .init(color: middleColor, location: 0.56),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
