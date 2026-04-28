import Foundation

struct ApplicationIndexer {
    private let searchRoots: [URL] = [
        URL(fileURLWithPath: "/Applications", isDirectory: true),
        URL(fileURLWithPath: "/System/Applications", isDirectory: true),
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications", isDirectory: true),
        URL(fileURLWithPath: "/System/Library/CoreServices/Applications", isDirectory: true)
    ]

    func indexApplications() async -> [ApplicationEntry] {
        await Task.detached(priority: .userInitiated) {
            Self.indexApplicationsSynchronously(searchRoots: searchRoots)
        }.value
    }

    private static func indexApplicationsSynchronously(searchRoots: [URL]) -> [ApplicationEntry] {
        let fileManager = FileManager.default
        var seenPaths = Set<String>()
        var entries: [ApplicationEntry] = []

        for root in searchRoots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isApplicationKey, .localizedNameKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let url as URL in enumerator {
                guard url.pathExtension == "app" else {
                    continue
                }

                let standardizedPath = url.standardizedFileURL.path

                guard !seenPaths.contains(standardizedPath) else {
                    enumerator.skipDescendants()
                    continue
                }

                seenPaths.insert(standardizedPath)
                entries.append(Self.makeEntry(for: url))
                enumerator.skipDescendants()
            }
        }

        return entries.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private static func makeEntry(for url: URL) -> ApplicationEntry {
        let bundle = Bundle(url: url)
        let displayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let bundleName = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
        let fallbackName = url.deletingPathExtension().lastPathComponent
        let name = displayName ?? bundleName ?? fallbackName
        let bundleIdentifier = bundle?.bundleIdentifier

        return ApplicationEntry(
            id: bundleIdentifier ?? url.standardizedFileURL.path,
            name: name,
            url: url,
            bundleIdentifier: bundleIdentifier
        )
    }
}
