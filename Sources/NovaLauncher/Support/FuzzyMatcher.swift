import Foundation

enum FuzzyMatcher {
    static func match(query: String, in applications: [ApplicationEntry], limit: Int) -> [ApplicationEntry] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !normalizedQuery.isEmpty else {
            return []
        }

        let queryCharacters = Array(normalizedQuery)

        return applications
            .compactMap { application -> (ApplicationEntry, Int)? in
                guard let score = score(
                    queryCharacters,
                    queryString: normalizedQuery,
                    against: application
                ) else {
                    return nil
                }

                return (application, score)
            }
            .sorted {
                if $0.1 == $1.1 {
                    return $0.0.name.localizedStandardCompare($1.0.name) == .orderedAscending
                }

                return $0.1 > $1.1
            }
            .prefix(limit)
            .map(\.0)
    }

    private static func score(
        _ query: [Character],
        queryString: String,
        against application: ApplicationEntry
    ) -> Int? {
        guard !query.isEmpty else {
            return 0
        }

        let candidate = application.searchCharacters
        var queryIndex = 0
        var score = 0
        var consecutiveMatches = 0
        var lastMatchIndex = -1

        for candidateIndex in candidate.indices {
            guard queryIndex < query.count else {
                break
            }

            if candidate[candidateIndex] == query[queryIndex] {
                score += 10

                if candidateIndex == queryIndex {
                    score += 12
                }

                if lastMatchIndex + 1 == candidateIndex {
                    consecutiveMatches += 1
                    score += consecutiveMatches * 4
                } else {
                    consecutiveMatches = 0
                }

                lastMatchIndex = candidateIndex
                queryIndex += 1
            }
        }

        guard queryIndex == query.count else {
            return nil
        }

        if application.searchableName.hasPrefix(queryString) {
            score += 80
        }

        return score - candidate.count
    }
}
