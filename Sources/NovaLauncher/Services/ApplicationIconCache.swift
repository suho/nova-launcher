import AppKit

final class ApplicationIconCache {
    static let shared = ApplicationIconCache()

    private let cache = NSCache<NSString, NSImage>()
    private let inFlightQueue = DispatchQueue(label: "app.novalauncher.icon-cache.in-flight")
    private var inFlightTasks: [String: Task<NSImage, Never>] = [:]

    func cachedIcon(for url: URL) -> NSImage? {
        cache.object(forKey: url.path as NSString)
    }

    func icon(for url: URL) async -> NSImage {
        let path = url.path
        let key = path as NSString

        if let cachedIcon = cache.object(forKey: key) {
            return cachedIcon
        }

        let task = inFlightQueue.sync {
            if let inFlightTask = inFlightTasks[path] {
                return inFlightTask
            }

            let task = Task.detached(priority: .utility) {
                let image = NSWorkspace.shared.icon(forFile: path)
                image.size = NSSize(width: 64, height: 64)
                return image
            }
            inFlightTasks[path] = task
            return task
        }

        let icon = await task.value

        cache.setObject(icon, forKey: key)
        inFlightQueue.sync {
            inFlightTasks[path] = nil
        }

        return icon
    }

    func preload(_ applications: [ApplicationEntry]) async {
        for application in applications {
            _ = await icon(for: application.url)
        }
    }
}
