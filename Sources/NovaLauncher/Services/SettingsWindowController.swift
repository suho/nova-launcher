import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let store: LauncherStore
    private let hotKeyManager: HotKeyManager
    private var window: NSWindow?

    init(store: LauncherStore, hotKeyManager: HotKeyManager) {
        self.store = store
        self.hotKeyManager = hotKeyManager
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        if !window.isVisible {
            window.center()
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 760, height: 520)),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Nova Settings"
        window.contentViewController = NSHostingController(
            rootView: SettingsView(
                store: store,
                hotKeyManager: hotKeyManager
            )
        )
        window.setContentSize(NSSize(width: 760, height: 520))
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]

        return window
    }
}
