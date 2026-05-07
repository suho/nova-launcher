import Foundation
import Testing
@testable import NovaLauncher

struct LauncherSearchRankerTests {
    @Test func frecencyBreaksTiesAfterFuzzyScore() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let alpha = LauncherItem.application(sampleApplication(name: "Alpha"))
        let altar = LauncherItem.application(sampleApplication(name: "Altar"))
        let records = [
            altar.id: LauncherItemRankingRecord(useCount: 2, lastUsedAt: now)
        ]

        let rankedItems = LauncherSearchRanker.rank(
            query: "al",
            items: [alpha, altar],
            rankingRecords: records,
            now: now,
            limit: 2
        )

        #expect(rankedItems == [altar, alpha])
    }

    @Test func fuzzyScoreStaysAheadOfFrecencyScore() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let strongTitleMatch = LauncherItem.application(sampleApplication(name: "Alfred"))
        let weakerTitleMatch = LauncherItem.application(sampleApplication(name: "Scalds"))
        let records = [
            weakerTitleMatch.id: LauncherItemRankingRecord(useCount: 50, lastUsedAt: now)
        ]

        let rankedItems = LauncherSearchRanker.rank(
            query: "al",
            items: [weakerTitleMatch, strongTitleMatch],
            rankingRecords: records,
            now: now,
            limit: 2
        )

        #expect(rankedItems == [strongTitleMatch, weakerTitleMatch])
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
