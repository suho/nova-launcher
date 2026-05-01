import Foundation

@MainActor
final class AppServices {
    static let shared = AppServices()

    let launcherStore: LauncherStore
    let hotKeyManager: HotKeyManager
    private let panelController: CommandPanelController
    private let errorToastController: ErrorToastWindowController

    private init() {
        let store = LauncherStore()
        let hotKeyManager = HotKeyManager()

        self.launcherStore = store
        self.hotKeyManager = hotKeyManager
        self.panelController = CommandPanelController(store: store)
        self.errorToastController = ErrorToastWindowController()

        hotKeyManager.onPressed = { [weak self] in
            self?.toggleCommandPalette()
        }

        store.onItemConfigurationsChanged = { [weak self] in
            self?.syncItemHotKeys()
        }

        store.onErrorToastMessageChanged = { [weak self] message in
            self?.errorToastController.update(message: message)
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
