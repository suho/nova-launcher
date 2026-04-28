import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var store: LauncherStore
    let openLauncher: () -> Void

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Open Launcher") {
            openLauncher()
        }
        .keyboardShortcut(.space, modifiers: [.option])

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
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }
}
