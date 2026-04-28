import AppKit
import SwiftUI

struct AppIconView: View {
    let url: URL
    let size: CGFloat
    @State private var icon: NSImage?

    var body: some View {
        ZStack {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(.quaternary)

                Image(systemName: "app.dashed")
                    .font(.system(size: size * 0.48, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .task(id: url.path) {
            icon = await ApplicationIconCache.shared.icon(for: url)
        }
    }
}
