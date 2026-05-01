import SwiftUI

struct ContentView: View {
    @ObservedObject var store: LauncherStore
    let openLauncher: () -> Void

    @AppStorage("launchAtLogin.enabled") private var launchAtLogin = false
    @AppStorage("appearance.theme") private var themeRawValue = AppTheme.system.rawValue
    @State private var selectedSection: MainSection? = .setup

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                ForEach(MainSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            ScrollView {
                detailContent
                    .padding(28)
                    .frame(maxWidth: 880, alignment: .leading)
            }
            .background(.background)
        }
        .onAppear {
            AppearanceService.apply(currentTheme)
        }
        .onChange(of: themeRawValue) { _, newValue in
            AppearanceService.apply(rawValue: newValue)
        }
    }

    private var currentTheme: AppTheme {
        AppTheme(rawValue: themeRawValue) ?? .system
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedSection ?? .setup {
        case .setup:
            setupPage
        case .applications:
            applicationsPage
        case .appearance:
            appearancePage
        }
    }

    private var setupPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            setupGrid
            recentApps
        }
    }

    private var applicationsPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Applications")
                        .font(.system(size: 30, weight: .bold))

                    Text("\(store.applications.count) apps indexed locally")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

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

            if store.applications.isEmpty {
                ProgressView()
                    .controlSize(.small)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                    ForEach(store.applications) { application in
                        HStack(spacing: 10) {
                            AppIconView(url: application.url, size: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(application.name)
                                    .font(.callout.weight(.medium))
                                    .lineLimit(1)

                                Text(application.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .frame(height: 58)
                        .background(.quinary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }

    private var appearancePage: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Appearance")
                    .font(.system(size: 30, weight: .bold))

                Text("Choose how Nova follows macOS.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

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
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: theme.systemImage)
                            .font(.system(size: 20, weight: .semibold))

                        Text(theme.title)
                            .font(.callout.weight(.semibold))
                    }
                    .foregroundStyle(theme.rawValue == themeRawValue ? .primary : .secondary)
                    .padding(14)
                    .frame(width: 132, height: 92, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.quaternary)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 34, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: 76, height: 76)

            VStack(alignment: .leading, spacing: 6) {
                Text("Nova Launcher")
                    .font(.system(size: 34, weight: .bold))
                    .lineLimit(1)

                Text("Local app index: \(store.applications.count)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                openLauncher()
            } label: {
                Label("Open", systemImage: "command")
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
    }

    private var setupGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 14) {
            GridRow {
                SetupTile(
                    title: "Global Hotkey",
                    value: KeyboardShortcut.fromDefaults().displayString,
                    systemImage: "keyboard",
                    isComplete: true
                )

                SetupTile(
                    title: "Menu Bar",
                    value: "Active",
                    systemImage: "menubar.rectangle",
                    isComplete: true
                )
            }

            GridRow {
                SetupTile(
                    title: "Launch at Login",
                    value: launchAtLogin ? "Enabled" : "Off",
                    systemImage: "power",
                    isComplete: launchAtLogin
                ) {
                    Toggle("", isOn: launchAtLoginBinding)
                        .labelsHidden()
                }

                SetupTile(
                    title: "Local Index",
                    value: store.isIndexing ? "Indexing" : "Ready",
                    systemImage: "lock.shield",
                    isComplete: !store.applications.isEmpty
                ) {
                    Button {
                        Task {
                            await store.refreshApplications()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Refresh local application index")
                }
            }
        }
    }

    private var recentApps: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Applications")
                .font(.headline)

            if store.applications.isEmpty {
                ProgressView()
                    .controlSize(.small)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                    ForEach(store.applications.prefix(12)) { application in
                        HStack(spacing: 10) {
                            AppIconView(url: application.url, size: 28)
                            Text(application.name)
                                .font(.callout.weight(.medium))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .frame(height: 50)
                        .background(.quinary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
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
}

private enum MainSection: String, CaseIterable, Identifiable {
    case setup
    case applications
    case appearance

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .setup:
            "Setup"
        case .applications:
            "Applications"
        case .appearance:
            "Appearance"
        }
    }

    var systemImage: String {
        switch self {
        case .setup:
            "checklist"
        case .applications:
            "app.dashed"
        case .appearance:
            "paintpalette"
        }
    }
}

private struct SetupTile<Accessory: View>: View {
    let title: String
    let value: String
    let systemImage: String
    let isComplete: Bool
    @ViewBuilder let accessory: Accessory

    init(
        title: String,
        value: String,
        systemImage: String,
        isComplete: Bool,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.isComplete = isComplete
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isComplete ? .green : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)

                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
            accessory
        }
        .padding(14)
        .frame(minWidth: 280, minHeight: 78)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
