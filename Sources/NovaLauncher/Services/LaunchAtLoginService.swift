import Foundation
import ServiceManagement

enum LaunchAtLoginService {
    static var isEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: "launchAtLogin.enabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "launchAtLogin.enabled")
            updateLoginItem(isEnabled: newValue)
        }
    }

    private static func updateLoginItem(isEnabled: Bool) {
        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            UserDefaults.standard.set(false, forKey: "launchAtLogin.enabled")
        }
    }
}
