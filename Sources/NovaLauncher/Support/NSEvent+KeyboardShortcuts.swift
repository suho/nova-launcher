import AppKit
import Carbon

extension NSEvent {
    var isCommandCommaShortcut: Bool {
        guard type == .keyDown else {
            return false
        }

        let modifiers = modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.contains(.command),
              !modifiers.contains(.control),
              !modifiers.contains(.option),
              !modifiers.contains(.shift) else {
            return false
        }

        return charactersIgnoringModifiers == "," || keyCode == UInt16(kVK_ANSI_Comma)
    }
}
