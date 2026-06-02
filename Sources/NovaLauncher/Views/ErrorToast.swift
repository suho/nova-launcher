import SwiftUI

struct ErrorToast: View {
    let message: String
    let width: CGFloat

    @AppStorage("appearance.theme") private var themeRawValue = AppTheme.system.rawValue
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
                    .foregroundStyle(theme.messageColor)
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
            .tint(theme.glassTint)
            .interactive()
    }

    private var theme: ErrorToastVisualTheme {
        effectiveColorScheme == .dark
            ? .dark
            : .light
    }

    private var effectiveColorScheme: ColorScheme {
        switch AppTheme(rawValue: themeRawValue) ?? .system {
        case .system:
            colorScheme
        case .light:
            .light
        case .dark:
            .dark
        }
    }

    private var toastShadowBacking: some View {
        toastShape
            .fill(theme.shadowFill)
            .shadow(
                color: theme.outerShadowColor,
                radius: theme.outerShadowRadius,
                y: theme.outerShadowY
            )
            .shadow(
                color: theme.middleShadowColor,
                radius: theme.middleShadowRadius,
                y: theme.middleShadowY
            )
            .shadow(
                color: theme.innerShadowColor,
                radius: theme.innerShadowRadius,
                y: theme.innerShadowY
            )
    }

    private var toastSurfaceStroke: some View {
        toastShape
            .strokeBorder(toastStrokeGradient, lineWidth: theme.strokeWidth)
    }

    private var toastStrokeGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: theme.strokeTopColor, location: 0),
                .init(color: theme.strokeMiddleColor, location: 0.56),
                .init(color: theme.strokeBottomColor, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct ErrorToastVisualTheme {
    let glassTint: Color
    let shadowFill: Color
    let outerShadowColor: Color
    let outerShadowRadius: CGFloat
    let outerShadowY: CGFloat
    let middleShadowColor: Color
    let middleShadowRadius: CGFloat
    let middleShadowY: CGFloat
    let innerShadowColor: Color
    let innerShadowRadius: CGFloat
    let innerShadowY: CGFloat
    let strokeTopColor: Color
    let strokeMiddleColor: Color
    let strokeBottomColor: Color
    let strokeWidth: CGFloat
    let messageColor: Color

    static let light = ErrorToastVisualTheme(
        glassTint: .white.opacity(0.18),
        shadowFill: .white.opacity(0.04),
        outerShadowColor: .black.opacity(0.08),
        outerShadowRadius: 64,
        outerShadowY: 24,
        middleShadowColor: .black.opacity(0.06),
        middleShadowRadius: 28,
        middleShadowY: 12,
        innerShadowColor: .black.opacity(0.035),
        innerShadowRadius: 36,
        innerShadowY: 0,
        strokeTopColor: .white.opacity(0.18),
        strokeMiddleColor: .white.opacity(0.06),
        strokeBottomColor: .black.opacity(0.035),
        strokeWidth: 1,
        messageColor: .black.opacity(0.92)
    )

    static let dark = ErrorToastVisualTheme(
        glassTint: .black.opacity(0.42),
        shadowFill: .black.opacity(0.10),
        outerShadowColor: .black.opacity(0.22),
        outerShadowRadius: 26,
        outerShadowY: 12,
        middleShadowColor: .black.opacity(0.12),
        middleShadowRadius: 10,
        middleShadowY: 4,
        innerShadowColor: .black.opacity(0.08),
        innerShadowRadius: 6,
        innerShadowY: 0,
        strokeTopColor: .white.opacity(0.18),
        strokeMiddleColor: .white.opacity(0.09),
        strokeBottomColor: .white.opacity(0.035),
        strokeWidth: 0.5,
        messageColor: .white.opacity(0.94)
    )
}
