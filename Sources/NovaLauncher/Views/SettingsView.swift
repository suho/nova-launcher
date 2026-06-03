import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: LauncherStore
    @ObservedObject var hotKeyManager: HotKeyManager

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("launchAtLogin.enabled") private var launchAtLogin = false
    @AppStorage("appearance.theme") private var themeRawValue = AppTheme.system.rawValue
    @AppStorage(KeyboardShortcut.keyCodeDefaultsKey) private var shortcutKeyCode = Int(KeyboardShortcut.defaultShortcut.keyCode)
    @AppStorage(KeyboardShortcut.modifiersDefaultsKey) private var shortcutModifiers = Int(KeyboardShortcut.defaultShortcut.modifiers)
    @State private var selectedSection: SettingsSection = .general
    @State private var accessibilityPermissionGranted = AccessibilityPermissionService.isTrusted()
    @State private var recordingItemID: LauncherItem.ID?
    @State private var itemSearchQuery = ""

    var body: some View {
        GlassEffectContainer(spacing: 18) {
            HStack(spacing: 0) {
                sidebar

                Divider()
                    .opacity(0.34)

                detailColumn
            }
        }
        .frame(width: 900, height: 620)
        .background(settingsWindowBackground)
        .onAppear {
            AppearanceService.apply(currentTheme)
            refreshAccessibilityPermission()
        }
        .onChange(of: themeRawValue) { _, newValue in
            AppearanceService.apply(rawValue: newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshAccessibilityPermission()
        }
    }

    private var currentTheme: AppTheme {
        AppTheme(rawValue: themeRawValue) ?? .system
    }

    private var settingsWindowBackground: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .ignoresSafeArea()
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
                .frame(height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text("Nova")
                    .font(.system(size: 22, weight: .bold))

                Text("Settings")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)

            VStack(spacing: 4) {
                ForEach(SettingsSection.allCases) { section in
                    SettingsSidebarRow(
                        section: section,
                        isSelected: selectedSection == section
                    ) {
                        selectedSection = section
                    }
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Label(hotKeyManager.statusMessage, systemImage: "keyboard")
                    .lineLimit(2)

                Label("\(store.applications.count) apps indexed", systemImage: "shippingbox")
                    .lineLimit(1)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .frame(width: 238)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(sidebarTint)
                .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .padding(10)
    }

    private var sidebarTint: Color {
        colorScheme == .dark ? .black.opacity(0.24) : .white.opacity(0.32)
    }

    private var detailColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                detailHeader

                detailContent
            }
            .padding(.horizontal, 34)
            .padding(.top, 34)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.visible)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var detailHeader: some View {
        HStack(spacing: 14) {
            SettingsIcon(systemImage: selectedSection.systemImage, tint: selectedSection.tint)
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(selectedSection.title)
                    .font(.system(size: 30, weight: .bold))

                Text(selectedSection.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedSection {
        case .general:
            generalPage
        case .items:
            itemsPage
        case .appearance:
            appearancePage
        case .privacy:
            privacyPage
        }
    }

    private var generalPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsGroup("Startup") {
                Toggle("Launch at Login", isOn: launchAtLoginBinding)
            }

            SettingsGroup("Launcher Shortcut") {
                SettingsRow("Shortcut", systemImage: "keyboard") {
                    KeyboardShortcutRecorder(shortcut: shortcutBinding)
                        .frame(width: 180, height: 34)
                }

                SettingsRow("Status", systemImage: "checkmark.circle") {
                    Text(hotKeyManager.statusMessage)
                        .foregroundStyle(.secondary)
                }
            }

            SettingsGroup("Index") {
                SettingsRow("Applications", systemImage: "app.dashed") {
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
                .buttonStyle(.glass)
            }

            SettingsGroup("Search Ranking") {
                SettingsRow("Learned Items", systemImage: "chart.line.uptrend.xyaxis") {
                    Text("\(store.learnedRankingItemCount)")
                        .foregroundStyle(.secondary)
                }

                Button {
                    store.resetRanking()
                } label: {
                    Label("Reset Ranking", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.glass)
                .disabled(store.learnedRankingItemCount == 0)
            }
        }
    }

    private var itemsPage: some View {
        let commandItems = ItemSearchFilter.match(query: itemSearchQuery, in: store.commandItems)
        let applicationItems = ItemSearchFilter.match(query: itemSearchQuery, in: store.applicationItems)
        let isSearching = !itemSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(hotKeyManager.itemStatusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    Task {
                        await store.refreshApplications()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.glass)
            }

            ItemSearchField(query: $itemSearchQuery)

            List {
                if !commandItems.isEmpty {
                    Section("Window Management") {
                        ForEach(commandItems) { item in
                            itemConfigurationRow(for: item)
                        }
                    }
                }

                if !applicationItems.isEmpty || (!isSearching && store.applicationItems.isEmpty) {
                    Section("Applications") {
                        if store.applicationItems.isEmpty {
                            Text("Indexing Applications")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(applicationItems) { item in
                                itemConfigurationRow(for: item)
                            }
                        }
                    }
                }

                if isSearching && commandItems.isEmpty && applicationItems.isEmpty {
                    Section {
                        Text("No Matching Items")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .background(.clear)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .frame(minHeight: 330)
        }
        .padding(18)
        .settingsGlassSurface(cornerRadius: 24)
    }

    private var appearancePage: some View {
        SettingsGroup("Theme") {
            Picker("Theme", selection: $themeRawValue) {
                ForEach(AppTheme.allCases) { theme in
                    Label(theme.title, systemImage: theme.systemImage)
                        .tag(theme.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)

            HStack(spacing: 12) {
                ForEach(AppTheme.allCases) { theme in
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: theme.systemImage)
                            .font(.system(size: 20, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)

                        Text(theme.title)
                            .font(.callout.weight(.semibold))
                    }
                    .foregroundStyle(theme.rawValue == themeRawValue ? .primary : .secondary)
                    .padding(14)
                    .frame(width: 132, height: 92, alignment: .leading)
                    .background(.quinary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private var privacyPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsGroup("Window Management") {
                SettingsRow("Accessibility", systemImage: "figure") {
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
                    .buttonStyle(.glass)

                    Button {
                        refreshAccessibilityPermission()
                    } label: {
                        Label("Check Again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.glass)
                }
            }

            SettingsGroup("Privacy") {
                SettingsRow("Indexing", systemImage: "internaldrive") {
                    Text("Local")
                        .foregroundStyle(.secondary)
                }

                SettingsRow("Search Roots", systemImage: "folder") {
                    Text("/Applications")
                        .foregroundStyle(.secondary)
                }

                SettingsRow("Network", systemImage: "network.slash") {
                    Text("Off")
                        .foregroundStyle(.secondary)
                }
            }
        }
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

    private func itemConfigurationRow(for item: LauncherItem) -> some View {
        ItemConfigurationRow(
            item: item,
            configuration: store.configuration(for: item),
            isRecordingShortcut: recordingItemID == item.id,
            onBeginRecording: {
                recordingItemID = item.id
            },
            onEndRecording: {
                if recordingItemID == item.id {
                    recordingItemID = nil
                }
            },
            onEnabledChange: { isEnabled in
                store.setEnabled(isEnabled, for: item)
            },
            onShortcutChange: { shortcut in
                store.setShortcut(shortcut, for: item)
            }
        )
        .equatable()
    }
}

private struct ItemSearchField: View {
    @Binding var query: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField("Search apps and commands", text: $query)
                .textFieldStyle(.plain)
                .lineLimit(1)
                .accessibilityLabel("Search Items")

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Clear Search")
                .help("Clear Search")
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 10)
        .frame(width: 320, height: 32)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quinary)
                .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

private struct ItemConfigurationRow: View, Equatable {
    let item: LauncherItem
    let configuration: LauncherItemConfiguration
    let isRecordingShortcut: Bool
    let onBeginRecording: () -> Void
    let onEndRecording: () -> Void
    let onEnabledChange: (Bool) -> Void
    let onShortcutChange: (KeyboardShortcut?) -> Void

    static func == (lhs: ItemConfigurationRow, rhs: ItemConfigurationRow) -> Bool {
        lhs.item == rhs.item
            && lhs.configuration == rhs.configuration
            && lhs.isRecordingShortcut == rhs.isRecordingShortcut
    }

    var body: some View {
        HStack(spacing: 12) {
            Toggle("Enabled", isOn: enabledBinding)
                .labelsHidden()
                .help("Enabled")

            icon

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 16)

            shortcutEditor

            Button {
                onShortcutChange(nil)
                onEndRecording()
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .disabled(configuration.shortcut == nil)
            .help("Clear Hotkey")
        }
        .padding(.vertical, 4)
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: {
                configuration.isEnabled
            },
            set: onEnabledChange
        )
    }

    private var shortcutBinding: Binding<KeyboardShortcut?> {
        Binding(
            get: {
                configuration.shortcut
            },
            set: onShortcutChange
        )
    }

    @ViewBuilder
    private var shortcutEditor: some View {
        if isRecordingShortcut {
            KeyboardShortcutRecorder(
                optionalShortcut: shortcutBinding,
                placeholder: "None",
                startsRecordingOnAppear: true,
                onRecordingEnded: onEndRecording
            )
            .frame(width: 142, height: 30)
        } else {
            ShortcutDisplayButton(shortcut: configuration.shortcut, action: onBeginRecording)
                .frame(width: 142, height: 30)
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch item {
        case .application(let application):
            AppIconView(url: application.url, size: 28)
        case .windowCommand(let command):
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.secondary.opacity(0.12))

                Image(systemName: command.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary)
            }
            .frame(width: 28, height: 28)
        case .webURL:
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.secondary.opacity(0.12))

                Image(systemName: "globe")
                    .font(.system(size: 14, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary)
            }
            .frame(width: 28, height: 28)
        case .calculator:
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.secondary.opacity(0.12))

                Image(systemName: "equal")
                    .font(.system(size: 14, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary)
            }
            .frame(width: 28, height: 28)
        }
    }
}

private struct ShortcutDisplayButton: View {
    let shortcut: KeyboardShortcut?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(shortcut?.displayString ?? "None")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(shortcut == nil ? .secondary : .primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                }
        }
        .buttonStyle(.plain)
        .help("Record Hotkey")
    }
}
