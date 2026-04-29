import Foundation

@MainActor
final class LauncherStore: ObservableObject {
    @Published private(set) var applications: [ApplicationEntry] = []
    @Published private(set) var applicationItems: [LauncherItem] = []
    @Published private(set) var filteredItems: [LauncherItem] = []
    @Published private(set) var itemConfigurations = LauncherItemConfigurationPersistence.load()
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

    private let indexer = ApplicationIndexer()
    private let launcher = ApplicationLauncher()
    private let windowManager = WindowManagementService()
    private var focusedWindow: FocusedWindowContext?
    let commandItems = WindowCommand.allCases.map(LauncherItem.windowCommand)
    var onItemConfigurationsChanged: (() -> Void)?

    init() {
        Task {
            await refreshApplications()
        }
    }

    func beginPaletteSession() {
        let hasWindowAccess = windowManager.accessibilityTrusted(promptForPermission: true)
        focusedWindow = hasWindowAccess
            ? windowManager.captureFocusedWindow(promptForAccessibility: false)
            : nil
        focusedWindowDescription = focusedWindow?.displayName
        windowCommandUnavailableReason = hasWindowAccess
            ? "Focus a window before opening Nova"
            : "Grant Accessibility permission, then reopen Nova"
        query = ""
        selectedID = nil
        openingID = nil

        if applications.isEmpty {
            Task {
                await refreshApplications()
            }
        }
    }

    func refreshApplications() async {
        isIndexing = true
        let indexedApplications = await indexer.indexApplications()
        applications = indexedApplications
        applicationItems = indexedApplications.map(LauncherItem.application)
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
            let hasWindowAccess = windowManager.accessibilityTrusted(promptForPermission: true)
            let window = hasWindowAccess
                ? windowManager.captureFocusedWindow(promptForAccessibility: false)
                : nil

            focusedWindow = window
            focusedWindowDescription = window?.displayName
            windowCommandUnavailableReason = hasWindowAccess
                ? "Focus a window before using this shortcut"
                : "Grant Accessibility permission, then try again"
            perform(command, itemID: item.id, context: window, completion: {})
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
        completion: @escaping () -> Void
    ) {
        openingID = itemID

        do {
            statusMessage = try windowManager.perform(command, on: context)
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
}
