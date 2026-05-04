import Foundation

struct ApplicationIndexer {
    private static let defaultSearchRoots: [URL] = [
        URL(fileURLWithPath: "/Applications", isDirectory: true),
        URL(fileURLWithPath: "/System/Applications", isDirectory: true),
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications", isDirectory: true),
        URL(fileURLWithPath: "/System/Library/CoreServices/Applications", isDirectory: true)
    ]

    private static let defaultSpecialApplicationURLs: [URL] = [
        URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app", isDirectory: true)
    ]

    private let searchRoots: [URL]
    private let specialApplicationURLs: [URL]

    init(
        searchRoots: [URL] = Self.defaultSearchRoots,
        specialApplicationURLs: [URL] = Self.defaultSpecialApplicationURLs
    ) {
        self.searchRoots = searchRoots
        self.specialApplicationURLs = specialApplicationURLs
    }

    func indexApplications() async -> [ApplicationEntry] {
        await Task.detached(priority: .userInitiated) {
            Self.indexApplicationsSynchronously(
                searchRoots: searchRoots,
                specialApplicationURLs: specialApplicationURLs
            )
        }.value
    }

    private static func indexApplicationsSynchronously(
        searchRoots: [URL],
        specialApplicationURLs: [URL]
    ) -> [ApplicationEntry] {
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

                appendEntry(for: url, seenPaths: &seenPaths, entries: &entries)
                enumerator.skipDescendants()
            }
        }

        for url in specialApplicationURLs
            where fileManager.fileExists(atPath: url.path) && url.pathExtension == "app" {
            appendEntry(for: url, seenPaths: &seenPaths, entries: &entries)
        }

        return entries.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private static func appendEntry(
        for url: URL,
        seenPaths: inout Set<String>,
        entries: inout [ApplicationEntry]
    ) {
        let standardizedPath = url.standardizedFileURL.path

        guard !seenPaths.contains(standardizedPath) else {
            return
        }

        seenPaths.insert(standardizedPath)
        entries.append(Self.makeEntry(for: url))
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
