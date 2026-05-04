import SwiftUI

@main
@MainActor
struct NovaLauncherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private var services: AppServices {
        AppServices.shared
    }

    var body: some Scene {
        MenuBarExtra(AppMetadata.menuBarTitle, systemImage: "command") {
            MenuBarContentView(
                store: services.launcherStore,
                openLauncher: { services.showCommandPalette() },
                openSettings: { services.showSettings() }
            )
        }
        .menuBarExtraStyle(.menu)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    services.showSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
