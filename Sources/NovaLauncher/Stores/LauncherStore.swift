import Foundation

@MainActor
final class LauncherStore: ObservableObject {
    @Published private(set) var applications: [ApplicationEntry] = []
    @Published private(set) var filteredApplications: [ApplicationEntry] = []
    @Published private(set) var isIndexing = false
    @Published var query = "" {
        didSet {
            guard query != oldValue else {
                return
            }

            updateFilteredApplications()
        }
    }
    @Published var selectedID: ApplicationEntry.ID?
    @Published var openingID: ApplicationEntry.ID?
    @Published var lastOpenedName: String?

    private let indexer = ApplicationIndexer()
    private let launcher = ApplicationLauncher()

    init() {
        Task {
            await refreshApplications()
        }
    }

    func beginPaletteSession() {
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
        updateFilteredApplications()
        isIndexing = false

        Task.detached(priority: .utility) {
            await ApplicationIconCache.shared.preload(Array(indexedApplications.prefix(80)))
        }
    }

    func selectFirstResult() {
        selectedID = filteredApplications.first?.id
    }

    func moveSelection(by offset: Int) {
        let results = filteredApplications

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
        let results = filteredApplications
        let application = selectedID.flatMap { selectedID in
            results.first { $0.id == selectedID }
        } ?? results.first

        guard let application else {
            return
        }

        open(application, completion: completion)
    }

    func open(_ application: ApplicationEntry, completion: @escaping () -> Void) {
        openingID = application.id
        lastOpenedName = application.name

        launcher.open(application) { [weak self] success in
            guard let self else {
                completion()
                return
            }

            if success {
                self.query = ""
                self.selectedID = nil
                completion()
            }

            self.openingID = nil
        }
    }

    private func updateFilteredApplications() {
        filteredApplications = FuzzyMatcher.match(query: query, in: applications, limit: 8)
        selectedID = filteredApplications.first?.id
    }
}
