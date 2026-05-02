import Foundation
import Testing
@testable import NovaLauncher

struct ItemSearchFilterTests {
    @Test func emptyQueryPreservesItemOrder() {
        let items: [LauncherItem] = [
            .windowCommand(.maximize),
            .application(sampleApplication(name: "Safari"))
        ]

        #expect(ItemSearchFilter.match(query: "  ", in: items) == items)
    }

    @Test func matchesApplicationNamesFuzzily() {
        let safari = LauncherItem.application(sampleApplication(name: "Safari"))
        let notes = LauncherItem.application(sampleApplication(name: "Notes"))

        #expect(ItemSearchFilter.match(query: "sf", in: [notes, safari]) == [safari])
    }

    @Test func matchesCommandNames() {
        let items: [LauncherItem] = [
            .windowCommand(.leftHalf),
            .windowCommand(.maximize),
            .windowCommand(.nextDesktop)
        ]

        #expect(ItemSearchFilter.match(query: "max", in: items) == [.windowCommand(.maximize)])
    }

    @Test func ignoresApplicationPathWhenFilteringByName() {
        let safari = LauncherItem.application(sampleApplication(name: "Safari"))

        #expect(ItemSearchFilter.match(query: "applications", in: [safari]).isEmpty)
    }

    private func sampleApplication(name: String) -> ApplicationEntry {
        ApplicationEntry(
            id: name.lowercased(),
            name: name,
            url: URL(fileURLWithPath: "/Applications/\(name).app"),
            bundleIdentifier: nil
        )
    }
}
