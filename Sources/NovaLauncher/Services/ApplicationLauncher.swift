import AppKit

@MainActor
final class ApplicationLauncher {
    func open(_ application: ApplicationEntry, completion: @escaping (Bool) -> Void) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.openApplication(at: application.url, configuration: configuration) { _, error in
            Task { @MainActor in
                if error == nil {
                    completion(true)
                } else {
                    completion(NSWorkspace.shared.open(application.url))
                }
            }
        }
    }

    func open(_ url: URL, completion: @escaping (Bool) -> Void) {
        completion(NSWorkspace.shared.open(url))
    }
}
