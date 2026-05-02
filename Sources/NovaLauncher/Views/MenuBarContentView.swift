import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var store: LauncherStore
    let openLauncher: () -> Void
    let openSettings: () -> Void

    @AppStorage(KeyboardShortcut.keyCodeDefaultsKey) private var shortcutKeyCode = Int(KeyboardShortcut.defaultShortcut.keyCode)
    @AppStorage(KeyboardShortcut.modifiersDefaultsKey) private var shortcutModifiers = Int(KeyboardShortcut.defaultShortcut.modifiers)

    var body: some View {
        Button("Open Launcher") {
            openLauncher()
        }
        .keyboardShortcut(launcherShortcut.swiftUIKeyboardShortcut)

        Button("Reindex Apps") {
            Task {
                await store.refreshApplications()
            }
        }

        Divider()

        Text("\(store.applications.count) apps indexed")

        Divider()

        Button("Settings") {
            openSettings()
        }

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }

    private var launcherShortcut: KeyboardShortcut {
        let shortcut = KeyboardShortcut(
            keyCode: UInt32(shortcutKeyCode),
            modifiers: UInt32(shortcutModifiers)
        )

        if shortcut.keyCode == 0 && shortcut.modifiers == 0 {
            return .defaultShortcut
        }

        return shortcut
    }
}
