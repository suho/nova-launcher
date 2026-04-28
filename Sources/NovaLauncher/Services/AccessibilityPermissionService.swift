import AppKit
import ApplicationServices

enum AccessibilityPermissionService {
    static func isTrusted(promptForPermission: Bool = false) -> Bool {
        guard promptForPermission else {
            return AXIsProcessTrusted()
        }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    @discardableResult
    static func openSystemSettings() -> Bool {
        let urls = [
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"),
            URL(string: "x-apple.systempreferences:com.apple.preference.security")
        ].compactMap(\.self)

        for url in urls where NSWorkspace.shared.open(url) {
            return true
        }

        return false
    }
}
