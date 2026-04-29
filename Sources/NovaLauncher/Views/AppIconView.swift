import AppKit
import SwiftUI

struct AppIconView: View {
    let url: URL
    let size: CGFloat
    @State private var icon: NSImage?
    @State private var iconPath: String?

    init(url: URL, size: CGFloat) {
        self.url = url
        self.size = size

        let cachedIcon = ApplicationIconCache.shared.cachedIcon(for: url)
        _icon = State(initialValue: cachedIcon)
        _iconPath = State(initialValue: cachedIcon == nil ? nil : url.path)
    }

    var body: some View {
        ZStack {
            if let displayedIcon {
                Image(nsImage: displayedIcon)
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
            let path = url.path

            if let cachedIcon = ApplicationIconCache.shared.cachedIcon(for: url) {
                icon = cachedIcon
                iconPath = path
                return
            }

            icon = nil
            iconPath = nil

            let loadedIcon = await ApplicationIconCache.shared.icon(for: url)
            icon = loadedIcon
            iconPath = path
        }
    }

    private var displayedIcon: NSImage? {
        if iconPath == url.path {
            return icon
        }

        return ApplicationIconCache.shared.cachedIcon(for: url)
    }
}
