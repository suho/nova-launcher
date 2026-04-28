import Foundation

@MainActor
final class LauncherStore: ObservableObject {
    @Published private(set) var applications: [ApplicationEntry] = []
    @Published private(set) var filteredItems: [LauncherItem] = []
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
    private let windowCommands = WindowCommand.allCases

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
        updateFilteredItems()
        isIndexing = false

        Task.detached(priority: .utility) {
            await ApplicationIconCache.shared.preload(Array(indexedApplications.prefix(80)))
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
        openingID = itemID

        do {
            statusMessage = try windowManager.perform(command, on: focusedWindow)
            query = ""
            selectedID = nil
            completion()
        } catch {
            statusMessage = error.localizedDescription
        }

        openingID = nil
    }

    private func updateFilteredItems() {
        filteredItems = FuzzyMatcher.match(query: query, in: allItems, limit: 8)
        selectedID = filteredItems.first?.id
    }

    private var allItems: [LauncherItem] {
        windowCommands.map(LauncherItem.windowCommand) + applications.map(LauncherItem.application)
    }
}
