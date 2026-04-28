import AppKit
import ApplicationServices
import Darwin

@MainActor
final class WindowManagementService {
    private let spacesController = SpacesController()

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
        guard let frame = frame(of: windowElement) else {
            return nil
        }

        let screen = screen(containing: frame)

        return FocusedWindowContext(
            applicationName: application.localizedName ?? "Focused App",
            windowTitle: stringAttribute(kAXTitleAttribute as CFString, from: windowElement),
            processIdentifier: application.processIdentifier,
            windowID: windowID(of: windowElement),
            displayIdentifier: screen.flatMap(displayIdentifier(for:)),
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
            guard let windowID = context.windowID else {
                throw WindowManagementError.windowNumberUnavailable
            }

            try spacesController.moveWindowToNextDesktop(
                windowID: windowID,
                preferredDisplayIdentifier: context.displayIdentifier
            )
            return "Moved \(context.applicationName) to next desktop"
        }
    }

    private func setWindow(_ window: AXUIElement, to placement: WindowPlacement) throws {
        guard let currentFrame = frame(of: window),
              let screen = screen(containing: currentFrame) ?? NSScreen.main ?? NSScreen.screens.first else {
            throw WindowManagementError.noScreen
        }

        let targetFrame = placement.frame(in: screen.visibleFrame)
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
        guard promptForPermission else {
            return AXIsProcessTrusted()
        }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
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

    private func windowID(of window: AXUIElement) -> CGWindowID? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, "AXWindowNumber" as CFString, &value) == .success,
              let number = value as? NSNumber else {
            return nil
        }

        return CGWindowID(number.uint32Value)
    }

    private func screen(containing frame: CGRect) -> NSScreen? {
        let center = CGPoint(x: frame.midX, y: frame.midY)

        if let containingScreen = NSScreen.screens.first(where: { $0.frame.contains(center) }) {
            return containingScreen
        }

        return NSScreen.screens.max { first, second in
            first.frame.intersection(frame).area < second.frame.intersection(frame).area
        }
    }

    private func displayIdentifier(for screen: NSScreen) -> String? {
        guard let displayNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let unmanagedUUID = CGDisplayCreateUUIDFromDisplayID(CGDirectDisplayID(displayNumber.uint32Value)) else {
            return nil
        }

        let uuid = unmanagedUUID.takeRetainedValue()
        return CFUUIDCreateString(nil, uuid) as String
    }
}

struct FocusedWindowContext {
    let applicationName: String
    let windowTitle: String?
    let processIdentifier: pid_t
    let windowID: CGWindowID?
    let displayIdentifier: String?
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
    case noNextDesktop
    case spacesUnavailable
    case unableToMoveWindow
    case unsupportedWindow
    case windowNumberUnavailable

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired:
            "Accessibility permission is required"
        case .noFocusedWindow:
            "No focused window was captured"
        case .noScreen:
            "Could not determine the window screen"
        case .noNextDesktop:
            "No next desktop is available"
        case .spacesUnavailable:
            "Desktop spaces are unavailable"
        case .unableToMoveWindow:
            "The focused window could not be moved"
        case .unsupportedWindow:
            "The focused window does not support this action"
        case .windowNumberUnavailable:
            "Could not identify the focused window"
        }
    }
}

private final class SpacesController {
    private typealias CGSConnectionID = Int32
    private typealias CGSSpaceID = UInt64
    private typealias MainConnectionFunction = @convention(c) () -> CGSConnectionID
    private typealias CopyManagedDisplaySpacesFunction = @convention(c) (CGSConnectionID) -> CFArray?
    private typealias CopyActiveMenuBarDisplayIdentifierFunction = @convention(c) (CGSConnectionID) -> CFString?
    private typealias MoveWindowsToManagedSpaceFunction = @convention(c) (CGSConnectionID, CFArray, CGSSpaceID) -> Int32

    private let mainConnection: MainConnectionFunction?
    private let copyManagedDisplaySpaces: CopyManagedDisplaySpacesFunction?
    private let copyActiveMenuBarDisplayIdentifier: CopyActiveMenuBarDisplayIdentifierFunction?
    private let moveWindowsToManagedSpace: MoveWindowsToManagedSpaceFunction?

    init() {
        guard let handle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY) else {
            mainConnection = nil
            copyManagedDisplaySpaces = nil
            copyActiveMenuBarDisplayIdentifier = nil
            moveWindowsToManagedSpace = nil
            return
        }

        mainConnection = Self.loadSymbol("CGSMainConnectionID", from: handle)
        copyManagedDisplaySpaces = Self.loadSymbol("CGSCopyManagedDisplaySpaces", from: handle)
        copyActiveMenuBarDisplayIdentifier = Self.loadSymbol("CGSCopyActiveMenuBarDisplayIdentifier", from: handle)
        moveWindowsToManagedSpace = Self.loadSymbol("CGSMoveWindowsToManagedSpace", from: handle)
    }

    func moveWindowToNextDesktop(windowID: CGWindowID, preferredDisplayIdentifier: String?) throws {
        guard let mainConnection,
              let copyManagedDisplaySpaces,
              let moveWindowsToManagedSpace else {
            throw WindowManagementError.spacesUnavailable
        }

        let connection = mainConnection()
        guard let managedDisplaySpaces = copyManagedDisplaySpaces(connection),
              let displays = managedDisplaySpaces as? [[String: Any]],
              let display = displayDictionary(
                preferredDisplayIdentifier: preferredDisplayIdentifier,
                activeDisplayIdentifier: activeDisplayIdentifier(connection),
                displays: displays
              ),
              let currentSpace = display["Current Space"] as? [String: Any],
              let currentSpaceID = Self.spaceID(from: currentSpace),
              let spaces = display["Spaces"] as? [[String: Any]] else {
            throw WindowManagementError.spacesUnavailable
        }

        let desktopSpaces = spaces.filter(Self.isDesktopSpace)
        guard desktopSpaces.count > 1,
              let currentIndex = desktopSpaces.firstIndex(where: { Self.spaceID(from: $0) == currentSpaceID }) else {
            throw WindowManagementError.noNextDesktop
        }

        let nextIndex = desktopSpaces.index(after: currentIndex) == desktopSpaces.endIndex
            ? desktopSpaces.startIndex
            : desktopSpaces.index(after: currentIndex)

        guard let nextSpaceID = Self.spaceID(from: desktopSpaces[nextIndex]),
              nextSpaceID != currentSpaceID else {
            throw WindowManagementError.noNextDesktop
        }

        let windows = [NSNumber(value: windowID)] as CFArray
        let result = moveWindowsToManagedSpace(connection, windows, nextSpaceID)

        guard result == 0 else {
            throw WindowManagementError.unableToMoveWindow
        }
    }

    private func activeDisplayIdentifier(_ connection: CGSConnectionID) -> String? {
        guard let copyActiveMenuBarDisplayIdentifier else {
            return nil
        }

        return copyActiveMenuBarDisplayIdentifier(connection) as String?
    }

    private func displayDictionary(
        preferredDisplayIdentifier: String?,
        activeDisplayIdentifier: String?,
        displays: [[String: Any]]
    ) -> [String: Any]? {
        if let preferredDisplayIdentifier,
           let display = displays.first(where: { ($0["Display Identifier"] as? String) == preferredDisplayIdentifier }) {
            return display
        }

        if let activeDisplayIdentifier,
           let display = displays.first(where: { ($0["Display Identifier"] as? String) == activeDisplayIdentifier }) {
            return display
        }

        return displays.first
    }

    private static func isDesktopSpace(_ space: [String: Any]) -> Bool {
        guard let type = space["type"] as? NSNumber else {
            return true
        }

        return type.intValue == 0
    }

    private static func spaceID(from space: [String: Any]) -> CGSSpaceID? {
        for key in ["id", "ManagedSpaceID", "managedSpaceID"] {
            if let number = space[key] as? NSNumber {
                return number.uint64Value
            }

            if let integer = space[key] as? Int {
                return CGSSpaceID(integer)
            }

            if let unsignedInteger = space[key] as? UInt64 {
                return unsignedInteger
            }
        }

        return nil
    }

    private static func loadSymbol<Symbol>(_ name: String, from handle: UnsafeMutableRawPointer) -> Symbol? {
        guard let symbol = dlsym(handle, name) else {
            return nil
        }

        return unsafeBitCast(symbol, to: Symbol.self)
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
