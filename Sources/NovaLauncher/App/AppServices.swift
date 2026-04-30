import Foundation

@MainActor
final class AppServices {
    static let shared = AppServices()

    let launcherStore: LauncherStore
    let hotKeyManager: HotKeyManager
    private let panelController: CommandPanelController

    private init() {
        let store = LauncherStore()
        let hotKeyManager = HotKeyManager()

        self.launcherStore = store
        self.hotKeyManager = hotKeyManager
        self.panelController = CommandPanelController(store: store)

        hotKeyManager.onPressed = { [weak self] in
            self?.toggleCommandPalette()
        }

        store.onItemConfigurationsChanged = { [weak self] in
            self?.syncItemHotKeys()
        }
    }

    func start() {
        AppearanceService.apply(rawValue: UserDefaults.standard.string(forKey: "appearance.theme") ?? AppTheme.system.rawValue)
        hotKeyManager.start()
        syncItemHotKeys()
    }

    func showCommandPalette() {
        panelController.show()
    }

    func toggleCommandPalette() {
        panelController.toggle()
    }

    private func syncItemHotKeys() {
        let registrations = launcherStore.configuredHotKeyItems().map { item, shortcut in
            ItemHotKeyRegistration(id: item.id, shortcut: shortcut) { [weak self] in
                self?.launcherStore.openFromHotKey(item)
            }
        }

        hotKeyManager.updateItemShortcuts(registrations)
    }
}
