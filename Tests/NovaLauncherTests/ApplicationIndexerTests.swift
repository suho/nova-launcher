import Foundation
import Testing
@testable import NovaLauncher

struct ApplicationIndexerTests {
    @Test func includesSpecialApplicationsOutsideSearchRoots() async throws {
        let directory = try TemporaryApplicationDirectory()
        let searchRoot = directory.url.appendingPathComponent("Applications", isDirectory: true)
        let specialRoot = directory.url.appendingPathComponent("CoreServices", isDirectory: true)
        try FileManager.default.createDirectory(at: searchRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: specialRoot, withIntermediateDirectories: true)

        let notesURL = searchRoot.appendingPathComponent("Notes.app", isDirectory: true)
        let finderURL = specialRoot.appendingPathComponent("Finder.app", isDirectory: true)
        try makeApplicationBundle(
            at: notesURL,
            displayName: "Notes",
            bundleIdentifier: "com.example.notes"
        )
        try makeApplicationBundle(
            at: finderURL,
            displayName: "Finder",
            bundleIdentifier: "com.apple.finder"
        )

        let indexer = ApplicationIndexer(
            searchRoots: [searchRoot],
            specialApplicationURLs: [finderURL]
        )

        let applications = await indexer.indexApplications()

        #expect(applications.map(\.name) == ["Finder", "Notes"])
        #expect(applications.first { $0.name == "Finder" }?.bundleIdentifier == "com.apple.finder")
        #expect(applications.first { $0.name == "Notes" }?.id == "com.example.notes")
    }

    @Test func doesNotDuplicateSpecialApplicationsAlreadyFoundInSearchRoots() async throws {
        let directory = try TemporaryApplicationDirectory()
        let searchRoot = directory.url.appendingPathComponent("Applications", isDirectory: true)
        try FileManager.default.createDirectory(at: searchRoot, withIntermediateDirectories: true)

        let finderURL = searchRoot.appendingPathComponent("Finder.app", isDirectory: true)
        try makeApplicationBundle(
            at: finderURL,
            displayName: "Finder",
            bundleIdentifier: "com.apple.finder"
        )

        let indexer = ApplicationIndexer(
            searchRoots: [searchRoot],
            specialApplicationURLs: [finderURL]
        )

        let applications = await indexer.indexApplications()

        #expect(applications.map(\.name) == ["Finder"])
    }

    @Test func duplicateBundleIdentifiersKeepDistinctApplicationRows() async throws {
        let directory = try TemporaryApplicationDirectory()
        let searchRoot = directory.url.appendingPathComponent("Applications", isDirectory: true)
        try FileManager.default.createDirectory(at: searchRoot, withIntermediateDirectories: true)

        let xcode265URL = searchRoot.appendingPathComponent("Xcode-26.5.0.app", isDirectory: true)
        let xcode264URL = searchRoot.appendingPathComponent("Xcode-26.4.1.app", isDirectory: true)
        try makeApplicationBundle(
            at: xcode265URL,
            displayName: "Xcode",
            bundleIdentifier: "com.apple.dt.Xcode"
        )
        try makeApplicationBundle(
            at: xcode264URL,
            displayName: "Xcode",
            bundleIdentifier: "com.apple.dt.Xcode"
        )

        let indexer = ApplicationIndexer(
            searchRoots: [searchRoot],
            specialApplicationURLs: []
        )

        let applications = await indexer.indexApplications()
        let items = applications.map(LauncherItem.application)
        let rankedItems = LauncherSearchRanker.rank(
            query: "Xcode",
            items: items,
            rankingRecords: [:],
            limit: 8
        )

        #expect(applications.map(\.name) == ["Xcode-26.4.1", "Xcode-26.5.0"])
        #expect(Set(applications.map(\.id)).count == 2)
        #expect(Set(applications.map(\.bundleIdentifier)) == ["com.apple.dt.Xcode"])
        #expect(rankedItems.map(\.title) == ["Xcode-26.4.1", "Xcode-26.5.0"])
    }

    private func makeApplicationBundle(
        at url: URL,
        displayName: String,
        bundleIdentifier: String
    ) throws {
        let contentsURL = url.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)

        let infoPlist: [String: String] = [
            "CFBundleDisplayName": displayName,
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleName": displayName,
            "CFBundlePackageType": "APPL"
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: infoPlist,
            format: .xml,
            options: 0
        )
        try data.write(to: contentsURL.appendingPathComponent("Info.plist"))
    }
}

private final class TemporaryApplicationDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}
