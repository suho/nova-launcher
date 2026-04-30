import AppKit
import ApplicationServices

enum AccessibilityPermissionService {
    static func isTrusted(promptForPermission: Bool = false) -> Bool {
        let processIsTrusted = promptForPermission
            ? promptForTrust()
            : AXIsProcessTrusted()

        guard processIsTrusted else {
            return false
        }

        return canReadFocusedApplication()
    }

    private static func promptForTrust() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private static func canReadFocusedApplication() -> Bool {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedApplication: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApplication
        )

        guard result == .success,
              let focusedApplication,
              CFGetTypeID(focusedApplication) == AXUIElementGetTypeID() else {
            return false
        }

        return true
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
