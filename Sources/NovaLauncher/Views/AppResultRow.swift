import SwiftUI

struct AppResultRow: View {
    let item: LauncherItem
    let isSelected: Bool
    let isRunning: Bool
    let shortcut: KeyboardShortcut?
    let isOpening: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            icon

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    categoryLabel
                }
            }

            Spacer(minLength: 12)

            if let answer = calculatorAnswer {
                Text(answer)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityLabel("Answer \(answer)")
            }

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

    private var categoryLabel: some View {
        Text(item.categoryLabel)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background {
                Capsule()
                    .fill(.secondary.opacity(0.12))
            }
            .accessibilityLabel("Category \(item.categoryLabel)")
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
        case .calculator:
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.secondary.opacity(0.12))

                Image(systemName: "equal")
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary)
            }
            .frame(width: 36, height: 36)
        }
    }

    private var calculatorAnswer: String? {
        guard case .calculator(let result) = item else {
            return nil
        }

        return result.answerString
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selectionFillColor)
                .overlay {
                    if colorScheme == .light {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.white.opacity(0.28))
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(selectionStrokeColor, lineWidth: 1)
                }
        }
    }

    private var selectionFillColor: Color {
        Color.accentColor.opacity(colorScheme == .dark ? 0.34 : 0.16)
    }

    private var selectionStrokeColor: Color {
        Color.accentColor.opacity(colorScheme == .dark ? 0.72 : 0.42)
    }

    private func shortcutLabel(_ shortcut: KeyboardShortcut) -> some View {
        Button {} label: {
            Text(shortcut.displayString)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .glassEffect(.clear.interactive(), in: Capsule(style: .continuous))
        .contentShape(Capsule(style: .continuous))
        .allowsHitTesting(false)
        .accessibilityLabel("Shortcut \(shortcut.displayString)")
    }
}
