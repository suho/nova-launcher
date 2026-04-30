import Carbon
import SwiftUI

extension KeyboardShortcut {
    var swiftUIKeyboardShortcut: SwiftUI.KeyboardShortcut? {
        guard let keyEquivalent = swiftUIKeyEquivalent else {
            return nil
        }

        return SwiftUI.KeyboardShortcut(keyEquivalent, modifiers: swiftUIEventModifiers)
    }

    private var swiftUIKeyEquivalent: KeyEquivalent? {
        switch Int(keyCode) {
        case kVK_Space:
            return .space
        case kVK_Return:
            return .return
        case kVK_Tab:
            return .tab
        case kVK_Escape:
            return .escape
        case kVK_Delete:
            return .delete
        case kVK_ForwardDelete:
            return .deleteForward
        case kVK_LeftArrow:
            return .leftArrow
        case kVK_RightArrow:
            return .rightArrow
        case kVK_UpArrow:
            return .upArrow
        case kVK_DownArrow:
            return .downArrow
        default:
            let keyName = KeyCodeNames.displayName(for: keyCode)
            guard keyName.count == 1, let character = keyName.lowercased().first else {
                return nil
            }

            return KeyEquivalent(character)
        }
    }

    private var swiftUIEventModifiers: SwiftUI.EventModifiers {
        var eventModifiers = SwiftUI.EventModifiers()

        if modifiers & UInt32(controlKey) != 0 {
            eventModifiers.insert(SwiftUI.EventModifiers.control)
        }

        if modifiers & UInt32(optionKey) != 0 {
            eventModifiers.insert(SwiftUI.EventModifiers.option)
        }

        if modifiers & UInt32(shiftKey) != 0 {
            eventModifiers.insert(SwiftUI.EventModifiers.shift)
        }

        if modifiers & UInt32(cmdKey) != 0 {
            eventModifiers.insert(SwiftUI.EventModifiers.command)
        }

        return eventModifiers
    }
}
