import AppKit
import Carbon
import SwiftUI

struct KeyboardShortcutRecorder: NSViewRepresentable {
    @Binding private var shortcut: KeyboardShortcut?
    private let placeholder: String
    private let allowsClearing: Bool

    init(shortcut: Binding<KeyboardShortcut>) {
        _shortcut = Binding<KeyboardShortcut?>(
            get: {
                shortcut.wrappedValue
            },
            set: { newValue in
                if let newValue {
                    shortcut.wrappedValue = newValue
                }
            }
        )
        placeholder = "Set Shortcut"
        allowsClearing = false
    }

    init(optionalShortcut: Binding<KeyboardShortcut?>, placeholder: String = "Set Shortcut") {
        _shortcut = optionalShortcut
        self.placeholder = placeholder
        allowsClearing = true
    }

    func makeNSView(context: Context) -> ShortcutRecorderControl {
        let control = ShortcutRecorderControl()
        control.shortcut = shortcut
        control.placeholder = placeholder
        control.allowsClearing = allowsClearing
        control.onChange = { shortcut in
            self.shortcut = shortcut
        }
        return control
    }

    func updateNSView(_ nsView: ShortcutRecorderControl, context: Context) {
        nsView.shortcut = shortcut
        nsView.placeholder = placeholder
        nsView.allowsClearing = allowsClearing
        nsView.updateLabel()
    }
}

final class ShortcutRecorderControl: NSView {
    var shortcut: KeyboardShortcut? = KeyboardShortcut.defaultShortcut {
        didSet {
            updateLabel()
        }
    }

    var placeholder = "Set Shortcut" {
        didSet {
            updateLabel()
        }
    }

    var allowsClearing = false
    var onChange: ((KeyboardShortcut?) -> Void)?

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

        if allowsClearing,
           Int(event.keyCode) == kVK_Delete || Int(event.keyCode) == kVK_ForwardDelete {
            shortcut = nil
            isRecording = false
            onChange?(nil)
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
        label.stringValue = isRecording ? "Press Shortcut" : shortcut?.displayString ?? placeholder
        label.textColor = shortcut == nil ? .secondaryLabelColor : .labelColor
        layer?.borderWidth = isRecording ? 1 : 0
        layer?.borderColor = NSColor.keyboardFocusIndicatorColor.cgColor
    }
}
