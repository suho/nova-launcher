import AppKit
import Foundation

@MainActor
final class LauncherStore: ObservableObject {
    @Published private(set) var applications: [ApplicationEntry] = []
    @Published private(set) var applicationItems: [LauncherItem] = []
    @Published private(set) var filteredItems: [LauncherItem] = []
    @Published private(set) var itemConfigurations = LauncherItemConfigurationPersistence.load()
    @Published private(set) var runningApplicationIDs = Set<LauncherItem.ID>()
    @Published private(set) var isIndexing = false
    @Published var query = "" {
        didSet {
            guard query != oldValue else {
                return
            }

            updateFilteredItems()
        }
    }
    @Published var selectedID: LauncherItem.ID?
    @Published var openingID: LauncherItem.ID?
    @Published var statusMessage: String?
    @Published private(set) var focusedWindowDescription: String?
    @Published private(set) var windowCommandUnavailableReason = "Focus a window before opening Nova"
    @Published private(set) var shouldKeepPaletteOpenForAccessibilityRequest = false

    private let indexer = ApplicationIndexer()
    private let launcher = ApplicationLauncher()
    private let windowManager = WindowManagementService()
    private var workspaceObservers: [NSObjectProtocol] = []
    private var focusedWindow: FocusedWindowContext?
    let commandItems = WindowCommand.allCases.map(LauncherItem.windowCommand)
    var onItemConfigurationsChanged: (() -> Void)?

    init() {
        observeWorkspaceApplications()
        refreshRunningApplications()

        Task {
            await refreshApplications()
        }
    }

    deinit {
        let notificationCenter = NSWorkspace.shared.notificationCenter

        for observer in workspaceObservers {
            notificationCenter.removeObserver(observer)
        }
    }

    func beginPaletteSession() {
        query = ""
        selectedID = nil
        openingID = nil
        focusedWindow = nil
        focusedWindowDescription = nil
        windowCommandUnavailableReason = "Checking focused window"
        shouldKeepPaletteOpenForAccessibilityRequest = false

        if applications.isEmpty {
            Task {
                await refreshApplications()
            }
        }
    }

    func refreshPaletteContext() {
        refreshRunningApplications()

        refreshFocusedWindowContext(
            noWindowReason: "Focus a window before opening Nova",
            noPermissionReason: "Use this command to request Accessibility permission",
            promptForAccessibility: false
        )
    }

    func endPaletteSession() {
        shouldKeepPaletteOpenForAccessibilityRequest = false
    }

    func refreshApplications() async {
        isIndexing = true
        let indexedApplications = await indexer.indexApplications()
        applications = indexedApplications
        applicationItems = indexedApplications.map(LauncherItem.application)
        refreshRunningApplications()
        updateFilteredItems()
        isIndexing = false
        onItemConfigurationsChanged?()

        Task.detached(priority: .utility) {
            await ApplicationIconCache.shared.preload(indexedApplications)
        }
    }

    func selectFirstResult() {
        selectedID = filteredItems.first?.id
    }

    func moveSelection(by offset: Int) {
        let results = filteredItems

        guard !results.isEmpty else {
            selectedID = nil
            return
        }

        let currentIndex = selectedID.flatMap { selectedID in
            results.firstIndex { $0.id == selectedID }
        } ?? 0

        let nextIndex = (currentIndex + offset + results.count) % results.count
        selectedID = results[nextIndex].id
    }

    func openSelected(completion: @escaping () -> Void) {
        let results = filteredItems
        let item = selectedID.flatMap { selectedID in
            results.first { $0.id == selectedID }
        } ?? results.first

        guard let item else {
            return
        }

        open(item, completion: completion)
    }

    func open(_ item: LauncherItem, completion: @escaping () -> Void) {
        switch item {
        case .application(let application):
            open(application, itemID: item.id, completion: completion)
        case .windowCommand(let command):
            perform(command, itemID: item.id, completion: completion)
        }
    }

    func open(_ application: ApplicationEntry, completion: @escaping () -> Void) {
        open(application, itemID: LauncherItem.application(application).id, completion: completion)
    }

    func openFromHotKey(_ item: LauncherItem) {
        switch item {
        case .application(let application):
            open(application, itemID: item.id, completion: {})
        case .windowCommand(let command):
            perform(
                command,
                itemID: item.id,
                context: nil,
                noWindowReason: "Focus a window before using this shortcut",
                noPermissionReason: "Grant Accessibility permission, then try again",
                completion: {}
            )
        }
    }

    func configuration(for item: LauncherItem) -> LauncherItemConfiguration {
        itemConfigurations[item.id] ?? .default
    }

    func setEnabled(_ isEnabled: Bool, for item: LauncherItem) {
        var configuration = configuration(for: item)
        configuration.isEnabled = isEnabled
        saveConfiguration(configuration, for: item.id)
        updateFilteredItems()
    }

    func setShortcut(_ shortcut: KeyboardShortcut?, for item: LauncherItem) {
        var configuration = configuration(for: item)
        configuration.shortcut = shortcut
        saveConfiguration(configuration, for: item.id)
        onItemConfigurationsChanged?()
    }

    func configuredHotKeyItems() -> [(item: LauncherItem, shortcut: KeyboardShortcut)] {
        allItems.compactMap { item in
            guard let shortcut = configuration(for: item).shortcut else {
                return nil
            }

            return (item, shortcut)
        }
    }

    func subtitle(for item: LauncherItem) -> String {
        switch item {
        case .application:
            return item.subtitle
        case .windowCommand(let command):
            guard let focusedWindowDescription else {
                return windowCommandUnavailableReason
            }

            switch command {
            case .leftHalf:
                return "Move \(focusedWindowDescription) to the left half"
            case .rightHalf:
                return "Move \(focusedWindowDescription) to the right half"
            case .maximize:
                return "Maximize \(focusedWindowDescription)"
            case .nextDesktop:
                return "Move \(focusedWindowDescription) to the next desktop"
            }
        }
    }

    func isRunning(_ item: LauncherItem) -> Bool {
        runningApplicationIDs.contains(item.id)
    }

    private func open(_ application: ApplicationEntry, itemID: LauncherItem.ID, completion: @escaping () -> Void) {
        openingID = itemID
        statusMessage = "Opening \(application.name)"

        launcher.open(application) { [weak self] success in
            guard let self else {
                completion()
                return
            }

            if success {
                self.query = ""
                self.selectedID = nil
                self.statusMessage = "Opened \(application.name)"
                completion()
            }

            self.openingID = nil
        }
    }

    private func perform(_ command: WindowCommand, itemID: LauncherItem.ID, completion: @escaping () -> Void) {
        perform(command, itemID: itemID, context: focusedWindow, completion: completion)
    }

    private func perform(
        _ command: WindowCommand,
        itemID: LauncherItem.ID,
        context: FocusedWindowContext?,
        noWindowReason: String = "Focus a window before opening Nova",
        noPermissionReason: String = "Grant Accessibility permission, then try again",
        completion: @escaping () -> Void
    ) {
        openingID = itemID

        guard requestAccessibilityForWindowCommand() else {
            focusedWindow = nil
            focusedWindowDescription = nil
            windowCommandUnavailableReason = noPermissionReason
            statusMessage = noPermissionReason
            openingID = nil
            return
        }

        let commandContext = context ?? refreshFocusedWindowContext(
            noWindowReason: noWindowReason,
            noPermissionReason: noPermissionReason,
            promptForAccessibility: false
        )

        guard let commandContext else {
            statusMessage = noWindowReason
            openingID = nil
            return
        }

        do {
            statusMessage = try windowManager.perform(command, on: commandContext)
            query = ""
            selectedID = nil
            completion()
        } catch {
            statusMessage = error.localizedDescription
        }

        openingID = nil
    }

    private func updateFilteredItems() {
        filteredItems = FuzzyMatcher.match(query: query, in: searchableItems, limit: 8)
        selectedID = filteredItems.first?.id
    }

    @discardableResult
    private func refreshFocusedWindowContext(
        noWindowReason: String,
        noPermissionReason: String,
        promptForAccessibility: Bool
    ) -> FocusedWindowContext? {
        let hasWindowAccess = windowManager.accessibilityTrusted(promptForPermission: promptForAccessibility)
        let window = hasWindowAccess
            ? windowManager.captureFocusedWindow(promptForAccessibility: false)
            : nil

        focusedWindow = window
        focusedWindowDescription = window?.displayName
        windowCommandUnavailableReason = hasWindowAccess ? noWindowReason : noPermissionReason

        return window
    }

    private func requestAccessibilityForWindowCommand() -> Bool {
        guard !windowManager.accessibilityTrusted(promptForPermission: false) else {
            shouldKeepPaletteOpenForAccessibilityRequest = false
            return true
        }

        shouldKeepPaletteOpenForAccessibilityRequest = true
        let isTrusted = windowManager.accessibilityTrusted(promptForPermission: true)

        if isTrusted {
            shouldKeepPaletteOpenForAccessibilityRequest = false
        }

        return isTrusted
    }

    private func saveConfiguration(_ configuration: LauncherItemConfiguration, for itemID: LauncherItem.ID) {
        if configuration.isDefault {
            itemConfigurations.removeValue(forKey: itemID)
        } else {
            itemConfigurations[itemID] = configuration
        }

        LauncherItemConfigurationPersistence.save(itemConfigurations)
    }

    private var searchableItems: [LauncherItem] {
        allItems.filter { item in
            configuration(for: item).isEnabled
        }
    }

    private var allItems: [LauncherItem] {
        commandItems + applicationItems
    }

    private func observeWorkspaceApplications() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        let notifications = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification
        ]

        workspaceObservers = notifications.map { notification in
            notificationCenter.addObserver(forName: notification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshRunningApplications()
                }
            }
        }
    }

    private func refreshRunningApplications() {
        let runningApplications = NSWorkspace.shared.runningApplications
        runningApplicationIDs = Set(applications.compactMap { application in
            guard Self.isApplication(application, runningIn: runningApplications) else {
                return nil
            }

            return LauncherItem.application(application).id
        })
    }

    private static func isApplication(
        _ application: ApplicationEntry,
        runningIn runningApplications: [NSRunningApplication]
    ) -> Bool {
        runningApplications.contains { runningApplication in
            if let bundleIdentifier = application.bundleIdentifier,
               runningApplication.bundleIdentifier == bundleIdentifier {
                return true
            }

            guard let bundleURL = runningApplication.bundleURL else {
                return false
            }

            return bundleURL.standardizedFileURL == application.url.standardizedFileURL
        }
    }
}
