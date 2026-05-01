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
        Settings {
            SettingsView(
                store: services.launcherStore,
                hotKeyManager: services.hotKeyManager
            )
            .onAppear {
                AppearanceService.apply(currentTheme)
            }
            .onChange(of: themeRawValue) { _, newValue in
                AppearanceService.apply(rawValue: newValue)
            }
        }

        MenuBarExtra("Nova", systemImage: "command") {
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
