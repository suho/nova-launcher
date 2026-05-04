import Foundation

enum AppMetadata {
    static var displayName: String {
        infoString(for: "CFBundleDisplayName")
            ?? infoString(for: "CFBundleName")
            ?? "Nova Launcher"
    }

    static var menuBarTitle: String {
        displayName.localizedCaseInsensitiveContains("dev") ? "Nova Dev" : "Nova"
    }

    private static func infoString(for key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
