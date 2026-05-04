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
