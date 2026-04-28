import AppKit
import Carbon
import SwiftUI

struct KeyboardShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: KeyboardShortcut

    func makeNSView(context: Context) -> ShortcutRecorderControl {
        let control = ShortcutRecorderControl()
        control.shortcut = shortcut
        control.onChange = { shortcut in
            self.shortcut = shortcut
        }
        return control
    }

    func updateNSView(_ nsView: ShortcutRecorderControl, context: Context) {
        nsView.shortcut = shortcut
        nsView.updateLabel()
    }
}

final class ShortcutRecorderControl: NSView {
    var shortcut = KeyboardShortcut.defaultShortcut {
        didSet {
            updateLabel()
        }
    }

    var onChange: ((KeyboardShortcut) -> Void)?

    private let label = NSTextField(labelWithString: "")
    private var isRecording = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        label.alignment = .center
        label.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        updateLabel()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        isRecording = true
        window?.makeFirstResponder(self)
        updateLabel()
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        updateLabel()
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        if Int(event.keyCode) == kVK_Escape {
            isRecording = false
            updateLabel()
            return
        }

        let modifiers = KeyboardShortcut.carbonModifiers(from: event.modifierFlags)

        guard modifiers != 0 else {
            NSSound.beep()
            return
        }

        let newShortcut = KeyboardShortcut(
            keyCode: UInt32(event.keyCode),
            modifiers: modifiers
        )

        shortcut = newShortcut
        isRecording = false
        onChange?(newShortcut)
        updateLabel()
    }

    func updateLabel() {
        label.stringValue = isRecording ? "Press Shortcut" : shortcut.displayString
        layer?.borderWidth = isRecording ? 1 : 0
        layer?.borderColor = NSColor.keyboardFocusIndicatorColor.cgColor
    }
}
