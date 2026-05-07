import Foundation

struct LauncherItemRankingRecord: Codable, Equatable {
    var useCount: Int
    var lastUsedAt: Date

    init(useCount: Int = 0, lastUsedAt: Date = .distantPast) {
        self.useCount = useCount
        self.lastUsedAt = lastUsedAt
    }

    mutating func recordUse(at date: Date = Date()) {
        useCount = max(0, useCount) + 1
        lastUsedAt = date
    }

    func frecencyScore(now: Date = Date()) -> Double {
        guard useCount > 0 else {
            return 0
        }

        let ageDays = max(0, now.timeIntervalSince(lastUsedAt) / 86_400)
        let frequencyScore = Double(useCount) * 100
        let recencyScore = 100 / (1 + ageDays)

        return frequencyScore + recencyScore
    }
}

enum LauncherItemRankingPersistence {
    private static let defaultsKey = "launcher.itemRankingRecords"

    static func load() -> [String: LauncherItemRankingRecord] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            return [:]
        }

        do {
            return try JSONDecoder().decode([String: LauncherItemRankingRecord].self, from: data)
        } catch {
            return [:]
        }
    }

    static func save(_ records: [String: LauncherItemRankingRecord]) {
        guard !records.isEmpty else {
            reset()
            return
        }

        do {
            let data = try JSONEncoder().encode(records)
            UserDefaults.standard.set(data, forKey: defaultsKey)
        } catch {
            reset()
        }
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}
