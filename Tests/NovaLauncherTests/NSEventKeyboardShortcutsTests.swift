import AppKit
import Carbon
import Testing
@testable import NovaLauncher

struct NSEventKeyboardShortcutsTests {
    @Test func commandCommaMatchesSettingsShortcut() throws {
        let event = try #require(keyEvent(modifierFlags: [.command]))

        #expect(event.isCommandCommaShortcut)
    }

    @Test func extraEditingModifiersDoNotMatchSettingsShortcut() throws {
        let shifted = try #require(keyEvent(modifierFlags: [.command, .shift]))
        let optioned = try #require(keyEvent(modifierFlags: [.command, .option]))
        let controlled = try #require(keyEvent(modifierFlags: [.command, .control]))

        #expect(!shifted.isCommandCommaShortcut)
        #expect(!optioned.isCommandCommaShortcut)
        #expect(!controlled.isCommandCommaShortcut)
    }

    @Test func nonCommaKeyDoesNotMatchSettingsShortcut() throws {
        let event = try #require(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [.command],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: ".",
                charactersIgnoringModifiers: ".",
                isARepeat: false,
                keyCode: UInt16(kVK_ANSI_Period)
            )
        )

        #expect(!event.isCommandCommaShortcut)
    }

    private func keyEvent(modifierFlags: NSEvent.ModifierFlags) -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifierFlags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: ",",
            charactersIgnoringModifiers: ",",
            isARepeat: false,
            keyCode: UInt16(kVK_ANSI_Comma)
        )
    }
}
