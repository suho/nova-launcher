import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: LauncherStore
    @ObservedObject var hotKeyManager: HotKeyManager

    @AppStorage("launchAtLogin.enabled") private var launchAtLogin = false
    @AppStorage("appearance.theme") private var themeRawValue = AppTheme.system.rawValue
    @AppStorage(KeyboardShortcut.keyCodeDefaultsKey) private var shortcutKeyCode = Int(KeyboardShortcut.defaultShortcut.keyCode)
    @AppStorage(KeyboardShortcut.modifiersDefaultsKey) private var shortcutModifiers = Int(KeyboardShortcut.defaultShortcut.modifiers)
    @State private var accessibilityPermissionGranted = AccessibilityPermissionService.isTrusted()

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            shortcutsTab
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            appearanceTab
                .tabItem {
                    Label("Appearance", systemImage: "paintpalette")
                }

            privacyTab
                .tabItem {
                    Label("Privacy", systemImage: "lock.shield")
                }
        }
        .frame(width: 560, height: 360)
        .scenePadding()
        .onAppear(perform: refreshAccessibilityPermission)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshAccessibilityPermission()
        }
    }

    private var generalTab: some View {
        Form {
            Toggle("Launch at Login", isOn: launchAtLoginBinding)

            HStack {
                Text("Applications")
                Spacer()
                Text("\(store.applications.count)")
                    .foregroundStyle(.secondary)
            }

            Button {
                Task {
                    await store.refreshApplications()
                }
            } label: {
                Label("Refresh Index", systemImage: "arrow.clockwise")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var shortcutsTab: some View {
        Form {
            HStack {
                Text("Launcher")
                Spacer()
                KeyboardShortcutRecorder(shortcut: shortcutBinding)
                    .frame(width: 180, height: 34)
            }

            HStack {
                Text("Status")
                Spacer()
                Text(hotKeyManager.statusMessage)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var appearanceTab: some View {
        Form {
            Picker("Theme", selection: $themeRawValue) {
                ForEach(AppTheme.allCases) { theme in
                    Label(theme.title, systemImage: theme.systemImage)
                        .tag(theme.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
        .formStyle(.grouped)
        .padding()
    }

    private var privacyTab: some View {
        Form {
            Section("Window Management") {
                LabeledContent("Accessibility") {
                    Label(
                        accessibilityPermissionGranted ? "Allowed" : "Required",
                        systemImage: accessibilityPermissionGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(accessibilityPermissionGranted ? .green : .orange)
                }

                HStack {
                    Button {
                        AccessibilityPermissionService.openSystemSettings()
                    } label: {
                        Label("Open Accessibility Settings", systemImage: "gearshape")
                    }

                    Button {
                        accessibilityPermissionGranted = AccessibilityPermissionService.isTrusted(promptForPermission: true)
                    } label: {
                        Label("Check Again", systemImage: "arrow.clockwise")
                    }
                }
            }

            LabeledContent("Indexing") {
                Text("Local")
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Search Roots") {
                Text("/Applications")
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Network") {
                Text("Off")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var shortcutBinding: Binding<KeyboardShortcut> {
        Binding(
            get: {
                KeyboardShortcut(
                    keyCode: UInt32(shortcutKeyCode),
                    modifiers: UInt32(shortcutModifiers)
                )
            },
            set: { shortcut in
                shortcutKeyCode = Int(shortcut.keyCode)
                shortcutModifiers = Int(shortcut.modifiers)
                hotKeyManager.updateShortcut(shortcut)
            }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { newValue in
                launchAtLogin = newValue
                LaunchAtLoginService.isEnabled = newValue
            }
        )
    }

    private func refreshAccessibilityPermission() {
        accessibilityPermissionGranted = AccessibilityPermissionService.isTrusted()
    }
}
