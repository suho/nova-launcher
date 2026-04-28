import Foundation

struct ApplicationEntry: Identifiable, Hashable {
    let id: String
    let name: String
    let url: URL
    let bundleIdentifier: String?
    let searchableName: String
    let searchCharacters: [Character]

    init(id: String, name: String, url: URL, bundleIdentifier: String?) {
        self.id = id
        self.name = name
        self.url = url
        self.bundleIdentifier = bundleIdentifier

        let searchableName = name.lowercased()
        self.searchableName = searchableName
        self.searchCharacters = Array(searchableName)
    }

    var subtitle: String {
        url.deletingLastPathComponent().path
    }
}
