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
    @Published private(set) var errorToastMessage: String?
    @Published private(set) var focusedWindowDescription: String?
    @Published private(set) var windowCommandUnavailableReason = "Focus a window before opening Nova"

    private let indexer = ApplicationIndexer()
    private let launcher = ApplicationLauncher()
    private let windowManager = WindowManagementService()
    private var workspaceObservers: [NSObjectProtocol] = []
    private var errorToastDismissTask: Task<Void, Never>?
    private var focusedWindow: FocusedWindowContext?
    let commandItems = WindowCommand.allCases.map(LauncherItem.windowCommand)
    var onItemConfigurationsChanged: (() -> Void)?
    var onErrorToastMessageChanged: ((String?) -> Void)?

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
        clearErrorToast()
        focusedWindow = nil
        focusedWindowDescription = nil
        windowCommandUnavailableReason = "Checking focused window"

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
        case .webURL(let webURL):
            open(webURL, itemID: item.id, completion: completion)
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
        case .webURL:
            break
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
        case .application, .webURL:
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
        clearErrorToast()

        launcher.open(application) { [weak self] success in
            guard let self else {
                completion()
                return
            }

            if success {
                self.query = ""
                self.selectedID = nil
                self.clearErrorToast()
                completion()
            } else {
                self.showErrorToast("Could not open \(application.name)")
            }

            self.openingID = nil
        }
    }

    private func open(_ webURL: WebURLItem, itemID: LauncherItem.ID, completion: @escaping () -> Void) {
        openingID = itemID
        clearErrorToast()

        launcher.open(webURL.url) { [weak self] success in
            guard let self else {
                completion()
                return
            }

            if success {
                self.query = ""
                self.selectedID = nil
                self.clearErrorToast()
                completion()
            } else {
                self.showErrorToast("Could not open \(webURL.displayString)")
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
        clearErrorToast()

        guard requestAccessibilityForWindowCommand() else {
            focusedWindow = nil
            focusedWindowDescription = nil
            windowCommandUnavailableReason = noPermissionReason
            showErrorToast(noPermissionReason)
            openingID = nil
            completion()
            return
        }

        let commandContext = context ?? refreshFocusedWindowContext(
            noWindowReason: noWindowReason,
            noPermissionReason: noPermissionReason,
            promptForAccessibility: false
        )

        guard let commandContext else {
            showErrorToast(noWindowReason)
            openingID = nil
            return
        }

        do {
            _ = try windowManager.perform(command, on: commandContext)
            query = ""
            selectedID = nil
            clearErrorToast()
            completion()
        } catch {
            showErrorToast(error.localizedDescription)
        }

        openingID = nil
    }

    private func showErrorToast(_ message: String) {
        errorToastDismissTask?.cancel()
        setErrorToastMessage(message)
        errorToastDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)

            guard !Task.isCancelled else {
                return
            }

            self?.setErrorToastMessage(nil)
            self?.errorToastDismissTask = nil
        }
    }

    private func clearErrorToast() {
        errorToastDismissTask?.cancel()
        errorToastDismissTask = nil
        setErrorToastMessage(nil)
    }

    private func setErrorToastMessage(_ message: String?) {
        errorToastMessage = message
        onErrorToastMessageChanged?(message)
    }

    private func updateFilteredItems() {
        let resultLimit = 8
        let matchedItems = FuzzyMatcher.match(query: query, in: searchableItems, limit: resultLimit)

        if let webURL = WebURLItem(query: query) {
            filteredItems = [LauncherItem.webURL(webURL)] + matchedItems.prefix(resultLimit - 1)
        } else {
            filteredItems = matchedItems
        }

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
            return true
        }

        return windowManager.accessibilityTrusted(promptForPermission: true)
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
