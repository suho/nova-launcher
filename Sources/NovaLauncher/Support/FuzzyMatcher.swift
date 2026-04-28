import Foundation

protocol FuzzySearchable {
    var searchableName: String { get }
    var searchCharacters: [Character] { get }
    var sortName: String { get }
}

extension ApplicationEntry: FuzzySearchable {
    var sortName: String {
        name
    }
}

enum FuzzyMatcher {
    static func match<Candidate: FuzzySearchable>(query: String, in candidates: [Candidate], limit: Int) -> [Candidate] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !normalizedQuery.isEmpty else {
            return []
        }

        let queryCharacters = Array(normalizedQuery)

        return candidates
            .compactMap { candidate -> (Candidate, Int)? in
                guard let score = score(
                    queryCharacters,
                    queryString: normalizedQuery,
                    against: candidate
                ) else {
                    return nil
                }

                return (candidate, score)
            }
            .sorted {
                if $0.1 == $1.1 {
                    return $0.0.sortName.localizedStandardCompare($1.0.sortName) == .orderedAscending
                }

                return $0.1 > $1.1
            }
            .prefix(limit)
            .map(\.0)
    }

    private static func score(
        _ query: [Character],
        queryString: String,
        against candidate: some FuzzySearchable
    ) -> Int? {
        guard !query.isEmpty else {
            return 0
        }

        let candidateCharacters = candidate.searchCharacters
        var queryIndex = 0
        var score = 0
        var consecutiveMatches = 0
        var lastMatchIndex = -1

        for candidateIndex in candidateCharacters.indices {
            guard queryIndex < query.count else {
                break
            }

            if candidateCharacters[candidateIndex] == query[queryIndex] {
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

        if candidate.searchableName.hasPrefix(queryString) {
            score += 80
        }

        return score - candidateCharacters.count
    }
}
