import AppKit
import Carbon
import Foundation

struct KeyboardShortcut: Codable, Equatable, Hashable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let defaultShortcut = KeyboardShortcut(
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(optionKey)
    )

    static let keyCodeDefaultsKey = "shortcut.keyCode"
    static let modifiersDefaultsKey = "shortcut.modifiers"

    static func fromDefaults() -> KeyboardShortcut {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: keyCodeDefaultsKey) != nil else {
            return defaultShortcut
        }

        let keyCode = UInt32(defaults.integer(forKey: keyCodeDefaultsKey))
        let modifiers = UInt32(defaults.integer(forKey: modifiersDefaultsKey))

        if keyCode == 0 && modifiers == 0 {
            return defaultShortcut
        }

        return KeyboardShortcut(keyCode: keyCode, modifiers: modifiers)
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(Int(keyCode), forKey: Self.keyCodeDefaultsKey)
        defaults.set(Int(modifiers), forKey: Self.modifiersDefaultsKey)
    }

    var displayString: String {
        modifierDisplayString + keyDisplayString
    }

    var modifierDisplayString: String {
        var parts: [String] = []

        if modifiers & UInt32(controlKey) != 0 {
            parts.append("⌃")
        }

        if modifiers & UInt32(optionKey) != 0 {
            parts.append("⌥")
        }

        if modifiers & UInt32(shiftKey) != 0 {
            parts.append("⇧")
        }

        if modifiers & UInt32(cmdKey) != 0 {
            parts.append("⌘")
        }

        return parts.joined()
    }

    var keyDisplayString: String {
        KeyCodeNames.displayName(for: keyCode)
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0

        if flags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }

        if flags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }

        if flags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }

        if flags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }

        return modifiers
    }
}
