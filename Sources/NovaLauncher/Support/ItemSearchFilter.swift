import Foundation

enum ItemSearchFilter {
    static func match(query: String, in items: [LauncherItem]) -> [LauncherItem] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedQuery.isEmpty else {
            return items
        }

        let candidates = items.map(ItemNameSearchCandidate.init)
        return FuzzyMatcher.match(query: normalizedQuery, in: candidates, limit: items.count).map(\.item)
    }
}

private struct ItemNameSearchCandidate: FuzzySearchable {
    let item: LauncherItem

    var searchableName: String {
        item.title.lowercased()
    }

    var searchCharacters: [Character] {
        Array(searchableName)
    }

    var sortName: String {
        item.sortName
    }
}
