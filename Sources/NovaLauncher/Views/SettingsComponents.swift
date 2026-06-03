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
}

struct SettingsAlignedRow<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(title)
                .font(.body)

            Spacer(minLength: 24)

            content
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
    }
}

struct ThemePreviewButton: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ThemePreviewThumbnail(theme: theme)
                    .frame(width: 72, height: 42)
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 3)
                    }

                Text(theme.settingsPreviewTitle)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(width: 78)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(theme.title)
    }
}

private struct ThemePreviewThumbnail: View {
    let theme: AppTheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(backgroundGradient)

            HStack(spacing: 0) {
                if theme == .system {
                    previewWindow(isDark: false)
                    previewWindow(isDark: true)
                } else {
                    previewWindow(isDark: theme == .dark)
                }
            }
            .padding(5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(.black.opacity(0.16), lineWidth: 0.5)
        }
    }

    private var backgroundGradient: LinearGradient {
        switch theme {
        case .system:
            LinearGradient(
                colors: [.blue.opacity(0.34), .indigo.opacity(0.42)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .light:
            LinearGradient(
                colors: [.cyan.opacity(0.28), .blue.opacity(0.32)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .dark:
            LinearGradient(
                colors: [.blue.opacity(0.62), .black.opacity(0.86)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func previewWindow(isDark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Circle()
                    .fill(.red)
                Circle()
                    .fill(.yellow)
                Circle()
                    .fill(.green)
            }
            .frame(width: 22, height: 4)

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(isDark ? .white.opacity(0.20) : .blue.opacity(0.30))
                .frame(width: theme == .system ? 24 : 46, height: 6)

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(isDark ? .white.opacity(0.14) : .black.opacity(0.10))
                .frame(width: theme == .system ? 20 : 38, height: 5)
        }
        .padding(5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(isDark ? .black.opacity(0.78) : .white.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

private extension AppTheme {
    var settingsPreviewTitle: String {
        switch self {
        case .system:
            "Auto"
        case .light:
            "Light"
        case .dark:
            "Dark"
        }
    }
}
