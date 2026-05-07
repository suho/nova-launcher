import Foundation
import Testing
@testable import NovaLauncher

struct LauncherItemRankingTests {
    @Test func higherUseCountIncreasesFrecencyScore() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let frequent = LauncherItemRankingRecord(useCount: 3, lastUsedAt: now)
        let occasional = LauncherItemRankingRecord(useCount: 1, lastUsedAt: now)

        #expect(frequent.frecencyScore(now: now) > occasional.frecencyScore(now: now))
    }

    @Test func moreRecentUseIncreasesFrecencyScoreWhenFrequencyMatches() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let recent = LauncherItemRankingRecord(useCount: 1, lastUsedAt: now)
        let older = LauncherItemRankingRecord(
            useCount: 1,
            lastUsedAt: now.addingTimeInterval(-10 * 86_400)
        )

        #expect(recent.frecencyScore(now: now) > older.frecencyScore(now: now))
    }

    @Test func recordingUseIncrementsFrequencyAndUpdatesRecency() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        var record = LauncherItemRankingRecord()

        record.recordUse(at: now)

        #expect(record.useCount == 1)
        #expect(record.lastUsedAt == now)
    }
}
