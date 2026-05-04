import AppKit
import ApplicationServices

@MainActor
final class WindowManagementService {
    func captureFocusedWindow(promptForAccessibility: Bool) -> FocusedWindowContext? {
        guard accessibilityTrusted(promptForPermission: promptForAccessibility),
              let application = NSWorkspace.shared.frontmostApplication,
              application.processIdentifier != NSRunningApplication.current.processIdentifier else {
            return nil
        }

        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )

        guard result == .success,
              let focusedWindow,
              CFGetTypeID(focusedWindow) == AXUIElementGetTypeID() else {
            return nil
        }

        let windowElement = focusedWindow as! AXUIElement
        guard frame(of: windowElement) != nil else {
            return nil
        }

        return FocusedWindowContext(
            applicationName: application.localizedName ?? "Focused App",
            windowTitle: stringAttribute(kAXTitleAttribute as CFString, from: windowElement),
            processIdentifier: application.processIdentifier,
            window: windowElement
        )
    }

    func perform(_ command: WindowCommand, on context: FocusedWindowContext?) throws -> String {
        guard accessibilityTrusted(promptForPermission: true) else {
            throw WindowManagementError.accessibilityPermissionRequired
        }

        guard let context else {
            throw WindowManagementError.noFocusedWindow
        }

        switch command {
        case .leftHalf:
            try setWindow(context.window, to: .leftHalf)
            return "Moved \(context.applicationName) left"
        case .rightHalf:
            try setWindow(context.window, to: .rightHalf)
            return "Moved \(context.applicationName) right"
        case .maximize:
            try setWindow(context.window, to: .maximize)
            return "Maximized \(context.applicationName)"
        case .nextDesktop:
            try moveWindowToNextDisplay(context.window)
            return "Moved \(context.applicationName) to next display"
        }
    }

    private func setWindow(_ window: AXUIElement, to placement: WindowPlacement) throws {
        guard let currentFrame = frame(of: window),
              let displayID = display(containingAccessibilityFrame: currentFrame),
              let visibleFrame = visibleAccessibilityFrame(for: displayID) else {
            throw WindowManagementError.noScreen
        }

        let targetFrame = placement.frame(in: visibleFrame)
        try setWindow(window, to: targetFrame)
    }

    private func moveWindowToNextDisplay(_ window: AXUIElement) throws {
        guard let currentFrame = frame(of: window),
              let currentDisplayID = display(containingAccessibilityFrame: currentFrame) else {
            throw WindowManagementError.noScreen
        }

        let displayIDs = onlineDisplayIDs()
        guard displayIDs.count > 1,
              let currentIndex = displayIDs.firstIndex(of: currentDisplayID) else {
            throw WindowManagementError.noNextDisplay
        }

        let nextIndex = displayIDs.index(after: currentIndex) == displayIDs.endIndex
            ? displayIDs.startIndex
            : displayIDs.index(after: currentIndex)
        let targetDisplayID = displayIDs[nextIndex]

        guard let sourceFrame = visibleAccessibilityFrame(for: currentDisplayID),
              let targetFrame = visibleAccessibilityFrame(for: targetDisplayID) else {
            throw WindowManagementError.noScreen
        }

        let movedFrame = currentFrame.moved(from: sourceFrame, to: targetFrame)
        try setWindow(window, to: movedFrame)
    }

    private func setWindow(_ window: AXUIElement, to targetFrame: CGRect) throws {
        var targetPosition = targetFrame.origin
        var targetSize = targetFrame.size

        guard let positionValue = AXValueCreate(.cgPoint, &targetPosition),
              let sizeValue = AXValueCreate(.cgSize, &targetSize) else {
            throw WindowManagementError.unsupportedWindow
        }

        let positionResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        let sizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)

        guard positionResult == .success, sizeResult == .success else {
            throw WindowManagementError.unableToMoveWindow
        }
    }

    func accessibilityTrusted(promptForPermission: Bool) -> Bool {
        AccessibilityPermissionService.isTrusted(promptForPermission: promptForPermission)
    }

    private func frame(of window: AXUIElement) -> CGRect? {
        guard let position = pointAttribute(kAXPositionAttribute as CFString, from: window),
              let size = sizeAttribute(kAXSizeAttribute as CFString, from: window) else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    private func pointAttribute(_ attribute: CFString, from element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == .cgPoint else {
            return nil
        }

        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else {
            return nil
        }

        return point
    }

    private func sizeAttribute(_ attribute: CFString, from element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == .cgSize else {
            return nil
        }

        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else {
            return nil
        }

        return size
    }

    private func stringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }

        return value as? String
    }

    private func display(containingAccessibilityFrame frame: CGRect) -> CGDirectDisplayID? {
        let displays = onlineDisplayIDs()
        let center = CGPoint(x: frame.midX, y: frame.midY)

        if let containingDisplay = displays.first(where: { CGDisplayBounds($0).contains(center) }) {
            return containingDisplay
        }

        return displays.max { first, second in
            CGDisplayBounds(first).intersection(frame).area < CGDisplayBounds(second).intersection(frame).area
        }
    }

    private func onlineDisplayIDs() -> [CGDirectDisplayID] {
        var displayCount: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &displayCount) == .success,
              displayCount > 0 else {
            return []
        }

        var displayIDs = Array(repeating: CGDirectDisplayID(), count: Int(displayCount))
        guard CGGetOnlineDisplayList(displayCount, &displayIDs, &displayCount) == .success else {
            return []
        }

        return Array(displayIDs.prefix(Int(displayCount))).sorted { first, second in
            let firstBounds = CGDisplayBounds(first)
            let secondBounds = CGDisplayBounds(second)

            if firstBounds.minX == secondBounds.minX {
                return firstBounds.minY < secondBounds.minY
            }

            return firstBounds.minX < secondBounds.minX
        }
    }

    private func visibleAccessibilityFrame(for displayID: CGDirectDisplayID) -> CGRect? {
        let displayBounds = CGDisplayBounds(displayID)
        guard let screen = screen(for: displayID) else {
            return displayBounds
        }

        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        let leftInset = visibleFrame.minX - screenFrame.minX
        let rightInset = screenFrame.maxX - visibleFrame.maxX
        let topInset = screenFrame.maxY - visibleFrame.maxY
        let bottomInset = visibleFrame.minY - screenFrame.minY

        return CGRect(
            x: displayBounds.minX + leftInset,
            y: displayBounds.minY + topInset,
            width: displayBounds.width - leftInset - rightInset,
            height: displayBounds.height - topInset - bottomInset
        )
    }

    private func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { screen in
            guard let screenDisplayID = self.displayID(forScreen: screen) else {
                return false
            }

            return screenDisplayID == displayID
        }
    }

    private func displayID(forScreen screen: NSScreen) -> CGDirectDisplayID? {
        guard let displayNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }

        return CGDirectDisplayID(displayNumber.uint32Value)
    }
}

struct FocusedWindowContext {
    let applicationName: String
    let windowTitle: String?
    let processIdentifier: pid_t
    let window: AXUIElement

    var displayName: String {
        guard let windowTitle,
              !windowTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return applicationName
        }

        return "\(applicationName): \(windowTitle)"
    }
}

private enum WindowPlacement {
    case leftHalf
    case rightHalf
    case maximize

    func frame(in visibleFrame: CGRect) -> CGRect {
        let halfWidth = floor(visibleFrame.width / 2)

        switch self {
        case .leftHalf:
            return CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: halfWidth,
                height: visibleFrame.height
            )
        case .rightHalf:
            return CGRect(
                x: visibleFrame.minX + halfWidth,
                y: visibleFrame.minY,
                width: visibleFrame.width - halfWidth,
                height: visibleFrame.height
            )
        case .maximize:
            return visibleFrame
        }
    }
}

private enum WindowManagementError: LocalizedError {
    case accessibilityPermissionRequired
    case noFocusedWindow
    case noScreen
    case noNextDisplay
    case unableToMoveWindow
    case unsupportedWindow

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired:
            "Accessibility permission is required"
        case .noFocusedWindow:
            "No focused window was captured"
        case .noScreen:
            "Could not determine the window screen"
        case .noNextDisplay:
            "No next display is available"
        case .unableToMoveWindow:
            "The focused window could not be moved"
        case .unsupportedWindow:
            "The focused window does not support this action"
        }
    }
}

private extension CGRect {
    func moved(from sourceFrame: CGRect, to targetFrame: CGRect) -> CGRect {
        let width = min(size.width, targetFrame.width)
        let height = min(size.height, targetFrame.height)
        let relativeMidX = sourceFrame.width > 0 ? (midX - sourceFrame.minX) / sourceFrame.width : 0.5
        let relativeMidY = sourceFrame.height > 0 ? (midY - sourceFrame.minY) / sourceFrame.height : 0.5
        let targetMidX = targetFrame.minX + targetFrame.width * relativeMidX
        let targetMidY = targetFrame.minY + targetFrame.height * relativeMidY
        let proposedOrigin = CGPoint(x: targetMidX - width / 2, y: targetMidY - height / 2)

        return CGRect(
            x: min(max(proposedOrigin.x, targetFrame.minX), targetFrame.maxX - width),
            y: min(max(proposedOrigin.y, targetFrame.minY), targetFrame.maxY - height),
            width: width,
            height: height
        )
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull, !isEmpty else {
            return 0
        }

        return width * height
    }
}
