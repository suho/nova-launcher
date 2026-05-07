import Foundation

enum LauncherSearchRanker {
    static func rank(
        query: String,
        items: [LauncherItem],
        rankingRecords: [String: LauncherItemRankingRecord],
        now: Date = Date(),
        limit: Int
    ) -> [LauncherItem] {
        FuzzyMatcher.scoredMatches(query: query, in: items)
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }

                let lhsFrecency = rankingRecords[lhs.candidate.id]?.frecencyScore(now: now) ?? 0
                let rhsFrecency = rankingRecords[rhs.candidate.id]?.frecencyScore(now: now) ?? 0

                if lhsFrecency != rhsFrecency {
                    return lhsFrecency > rhsFrecency
                }

                return lhs.candidate.sortName.localizedStandardCompare(rhs.candidate.sortName) == .orderedAscending
            }
            .prefix(limit)
            .map(\.candidate)
    }
}
