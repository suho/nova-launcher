import AppKit
import SwiftUI

@main
@MainActor
struct NovaLauncherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("appearance.theme") private var themeRawValue = AppTheme.system.rawValue

    private var services: AppServices {
        AppServices.shared
    }

    var body: some Scene {
        WindowGroup("Nova Launcher", id: "main") {
            ContentView(
                store: services.launcherStore,
                openLauncher: { services.showCommandPalette() }
            )
            .preferredColorScheme(currentTheme.colorScheme)
            .frame(minWidth: 780, minHeight: 560)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Open Launcher") {
                    services.showCommandPalette()
                }
                .keyboardShortcut(.space, modifiers: [.option])
            }
        }

        Settings {
            SettingsView(
                store: services.launcherStore,
                hotKeyManager: services.hotKeyManager
            )
            .preferredColorScheme(currentTheme.colorScheme)
        }

        MenuBarExtra("Nova", systemImage: "sparkle.magnifyingglass") {
            MenuBarContentView(
                store: services.launcherStore,
                openLauncher: { services.showCommandPalette() }
            )
        }
        .menuBarExtraStyle(.menu)
    }

    private var currentTheme: AppTheme {
        AppTheme(rawValue: themeRawValue) ?? .system
    }
}
