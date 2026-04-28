import AppKit

actor ApplicationIconCache {
    static let shared = ApplicationIconCache()

    private var cache: [String: NSImage] = [:]

    func icon(for url: URL) async -> NSImage {
        let path = url.path

        if let cachedIcon = cache[path] {
            return cachedIcon
        }

        let icon = await Task.detached(priority: .utility) {
            let image = NSWorkspace.shared.icon(forFile: path)
            image.size = NSSize(width: 64, height: 64)
            return image
        }.value

        cache[path] = icon
        return icon
    }

    func preload(_ applications: [ApplicationEntry]) async {
        for application in applications {
            _ = await icon(for: application.url)
        }
    }
}
