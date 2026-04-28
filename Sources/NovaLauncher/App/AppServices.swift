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
    }

    func start() {
        hotKeyManager.start()
    }

    func showCommandPalette() {
        panelController.show()
    }

    func toggleCommandPalette() {
        panelController.toggle()
    }
}
