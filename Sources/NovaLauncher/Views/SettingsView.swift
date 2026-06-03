import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: LauncherStore
    @ObservedObject var hotKeyManager: HotKeyManager

    @AppStorage("launchAtLogin.enabled") private var launchAtLogin = false
    @AppStorage("appearance.theme") private var themeRawValue = AppTheme.system.rawValue
    @AppStorage(KeyboardShortcut.keyCodeDefaultsKey) private var shortcutKeyCode = Int(KeyboardShortcut.defaultShortcut.keyCode)
    @AppStorage(KeyboardShortcut.modifiersDefaultsKey) private var shortcutModifiers = Int(KeyboardShortcut.defaultShortcut.modifiers)
    @State private var selectedSection: SettingsSection? = .general
    @State private var backStack: [SettingsSection] = []
    @State private var forwardStack: [SettingsSection] = []
    @State private var accessibilityPermissionGranted = AccessibilityPermissionService.isTrusted()
    @State private var recordingItemID: LauncherItem.ID?
    @State private var itemSearchQuery = ""

    var body: some View {
        NavigationSplitView {
            List(selection: selectedSectionBinding) {
                ForEach(SettingsSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 210, ideal: 230)
        } detail: {
            detailColumn(for: selectedSection ?? .general)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    navigateBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(backStack.isEmpty)
                .keyboardShortcut("[", modifiers: .command)
                .help("Back")

                Button {
                    navigateForward()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(forwardStack.isEmpty)
                .keyboardShortcut("]", modifiers: .command)
                .help("Forward")

                Text((selectedSection ?? .general).title)
                    .font(.headline)
                    .lineLimit(1)
                    .padding(.trailing, 10)
            }
        }
        .frame(width: 900, height: 620)
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

    private var selectedSectionBinding: Binding<SettingsSection?> {
        Binding(
            get: {
                selectedSection
            },
            set: { newValue in
                guard let newValue else {
                    return
                }

                selectSection(newValue)
            }
        )
    }

    @ViewBuilder
    private func detailColumn(for section: SettingsSection) -> some View {
        if section == .items {
            detailContent(for: section)
                .padding(.horizontal, 28)
                .padding(.top, 22)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(.background)
        } else {
            ScrollView {
                detailContent(for: section)
                    .padding(.horizontal, 28)
                    .padding(.top, 22)
                    .padding(.bottom, 28)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(.background)
            .scrollIndicators(.automatic)
        }
    }

    @ViewBuilder
    private func detailContent(for section: SettingsSection) -> some View {
        switch section {
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
        Form {
            Section("Startup") {
                Toggle("Launch at Login", isOn: launchAtLoginBinding)
            }

            Section("Launcher Shortcut") {
                SettingsAlignedRow("Shortcut") {
                    KeyboardShortcutRecorder(shortcut: shortcutBinding)
                        .frame(width: 180, height: 34)
                }
            }

            Section("Index") {
                LabeledContent("Applications") {
                    HStack(spacing: 12) {
                        Text("\(store.applications.count)")
                            .foregroundStyle(.secondary)

                        Button {
                            Task {
                                await store.refreshApplications()
                            }
                        } label: {
                            Label("Refresh Index", systemImage: "arrow.clockwise")
                        }
                    }
                }
            }

            Section("Search Ranking") {
                LabeledContent("Learned Items") {
                    HStack(spacing: 12) {
                        Text("\(store.learnedRankingItemCount)")
                            .foregroundStyle(.secondary)

                        Button {
                            store.resetRanking()
                        } label: {
                            Label("Reset Ranking", systemImage: "arrow.counterclockwise")
                        }
                        .disabled(store.learnedRankingItemCount == 0)
                    }
                }
            }
        }
        .formStyle(.grouped)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var appearancePage: some View {
        Form {
            Section("Theme") {
                SettingsAlignedRow("Appearance") {
                    HStack(spacing: 12) {
                        ForEach(AppTheme.allCases) { theme in
                            ThemePreviewButton(
                                theme: theme,
                                isSelected: theme.rawValue == themeRawValue
                            ) {
                                themeRawValue = theme.rawValue
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var privacyPage: some View {
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
                        refreshAccessibilityPermission()
                    } label: {
                        Label("Check Again", systemImage: "arrow.clockwise")
                    }
                }
            }

            Section("Privacy") {
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
        }
        .formStyle(.grouped)
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

    private func selectSection(_ section: SettingsSection) {
        let currentSection = selectedSection ?? .general

        guard section != currentSection else {
            return
        }

        backStack.append(currentSection)
        forwardStack.removeAll()
        selectedSection = section
    }

    private func navigateBack() {
        guard let previousSection = backStack.popLast() else {
            return
        }

        if let currentSection = selectedSection {
            forwardStack.append(currentSection)
        }

        selectedSection = previousSection
    }

    private func navigateForward() {
        guard let nextSection = forwardStack.popLast() else {
            return
        }

        if let currentSection = selectedSection {
            backStack.append(currentSection)
        }

        selectedSection = nextSection
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
        .padding(.horizontal, 8)
        .frame(width: 280, height: 30)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
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
