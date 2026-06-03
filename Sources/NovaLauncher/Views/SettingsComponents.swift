import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case items
    case appearance
    case privacy

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .general:
            "General"
        case .items:
            "Items"
        case .appearance:
            "Appearance"
        case .privacy:
            "Privacy"
        }
    }

    var subtitle: String {
        switch self {
        case .general:
            "Startup, shortcut, indexing, and ranking."
        case .items:
            "Configure apps, commands, and custom hotkeys."
        case .appearance:
            "Choose how Nova follows macOS."
        case .privacy:
            "Review local indexing and required permissions."
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            "gearshape"
        case .items:
            "list.bullet.rectangle"
        case .appearance:
            "paintpalette"
        case .privacy:
            "lock.shield"
        }
    }

    var tint: Color {
        switch self {
        case .general:
            .gray
        case .items:
            .blue
        case .appearance:
            .purple
        case .privacy:
            .green
        }
    }
}

struct SettingsSidebarRow: View {
    let section: SettingsSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                SettingsIcon(systemImage: section.systemImage, tint: section.tint)
                    .frame(width: 30, height: 30)

                Text(section.title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 42)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.blue)
                        .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .white : .primary)
    }
}

struct SettingsIcon: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(tint.gradient)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
            }
            .shadow(color: tint.opacity(0.28), radius: 4, y: 2)
    }
}

struct SettingsGroup<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(16)
            .settingsGlassSurface(cornerRadius: 20)
        }
    }
}

struct SettingsRow<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(title)
                .font(.callout)

            Spacer(minLength: 18)

            content
                .font(.callout)
        }
        .frame(minHeight: 32)
    }
}

private struct SettingsGlassSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.quinary)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.16), lineWidth: 0.5)
            }
    }
}

extension View {
    func settingsGlassSurface(cornerRadius: CGFloat) -> some View {
        modifier(SettingsGlassSurfaceModifier(cornerRadius: cornerRadius))
    }
}
