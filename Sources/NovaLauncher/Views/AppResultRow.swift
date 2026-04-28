import SwiftUI

struct AppResultRow: View {
    let application: ApplicationEntry
    let isSelected: Bool
    let isOpening: Bool

    var body: some View {
        HStack(spacing: 12) {
            AppIconView(url: application.url, size: 36)

            Text(application.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 12)

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
    private var selectionBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.primary.opacity(0.1))
        }
    }
}
