import Foundation

struct LauncherItemConfiguration: Codable, Equatable {
    var isEnabled: Bool
    var shortcut: KeyboardShortcut?

    static let `default` = LauncherItemConfiguration(isEnabled: true, shortcut: nil)

    var isDefault: Bool {
        self == Self.default
    }
}

enum LauncherItemConfigurationPersistence {
    private static let defaultsKey = "launcher.itemConfigurations"

    static func load() -> [String: LauncherItemConfiguration] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            return [:]
        }

        do {
            return try JSONDecoder().decode([String: LauncherItemConfiguration].self, from: data)
        } catch {
            return [:]
        }
    }

    static func save(_ configurations: [String: LauncherItemConfiguration]) {
        do {
            let data = try JSONEncoder().encode(configurations)
            UserDefaults.standard.set(data, forKey: defaultsKey)
        } catch {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        }
    }
}
