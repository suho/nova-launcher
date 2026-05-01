import SwiftUI

struct AppResultRow: View {
    let item: LauncherItem
    let subtitle: String
    let isSelected: Bool
    let isRunning: Bool
    let shortcut: KeyboardShortcut?
    let isOpening: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            icon

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            if let shortcut {
                shortcutLabel(shortcut)
            }

            if isOpening {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
        .background(selectionBackground)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var icon: some View {
        switch item {
        case .application(let application):
            AppIconView(url: application.url, size: 36)
                .overlay(alignment: .bottom) {
                    if isRunning {
                        Circle()
                            .fill(.primary.opacity(0.58))
                            .frame(width: 5, height: 5)
                            .offset(y: 6)
                    }
                }
                .frame(width: 36, height: 42)
        case .windowCommand(let command):
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.secondary.opacity(0.12))

                Image(systemName: command.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary)
            }
            .frame(width: 36, height: 36)
        case .webURL:
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.secondary.opacity(0.12))

                Image(systemName: "globe")
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary)
            }
            .frame(width: 36, height: 36)
        }
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selectionFillColor)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(selectionStrokeColor, lineWidth: 1)
                }
        }
    }

    private var selectionFillColor: Color {
        Color.accentColor.opacity(colorScheme == .dark ? 0.34 : 0.18)
    }

    private var selectionStrokeColor: Color {
        Color.accentColor.opacity(colorScheme == .dark ? 0.72 : 0.46)
    }

    private func shortcutLabel(_ shortcut: KeyboardShortcut) -> some View {
        Text(shortcut.displayString)
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel("Shortcut \(shortcut.displayString)")
    }
}
