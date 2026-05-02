import AppKit
import Carbon
import SwiftUI

struct KeyboardShortcutRecorder: NSViewRepresentable {
    @Binding private var shortcut: KeyboardShortcut?
    private let placeholder: String
    private let allowsClearing: Bool
    private let startsRecordingOnAppear: Bool
    private let onRecordingEnded: (() -> Void)?

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
        startsRecordingOnAppear = false
        onRecordingEnded = nil
    }

    init(
        optionalShortcut: Binding<KeyboardShortcut?>,
        placeholder: String = "Set Shortcut",
        startsRecordingOnAppear: Bool = false,
        onRecordingEnded: (() -> Void)? = nil
    ) {
        _shortcut = optionalShortcut
        self.placeholder = placeholder
        allowsClearing = true
        self.startsRecordingOnAppear = startsRecordingOnAppear
        self.onRecordingEnded = onRecordingEnded
    }

    func makeNSView(context: Context) -> ShortcutRecorderControl {
        let control = ShortcutRecorderControl()
        control.shortcut = shortcut
        control.placeholder = placeholder
        control.allowsClearing = allowsClearing
        control.startsRecordingOnAppear = startsRecordingOnAppear
        control.onRecordingEnded = onRecordingEnded
        control.onChange = { shortcut in
            self.shortcut = shortcut
        }
        return control
    }

    func updateNSView(_ nsView: ShortcutRecorderControl, context: Context) {
        nsView.shortcut = shortcut
        nsView.placeholder = placeholder
        nsView.allowsClearing = allowsClearing
        nsView.startsRecordingOnAppear = startsRecordingOnAppear
        nsView.onRecordingEnded = onRecordingEnded
        nsView.updateLabel()
        nsView.startRecordingOnAppearIfNeeded()
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
    var startsRecordingOnAppear = false {
        didSet {
            if !startsRecordingOnAppear {
                didStartRecordingOnAppear = false
            }
        }
    }
    var onChange: ((KeyboardShortcut?) -> Void)?
    var onRecordingEnded: (() -> Void)?

    private let label = NSTextField(labelWithString: "")
    private var isRecording = false
    private var didStartRecordingOnAppear = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.cornerCurve = .continuous

        label.alignment = .center
        label.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
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
        didStartRecordingOnAppear = true
        beginRecording()
    }

    override func resignFirstResponder() -> Bool {
        finishRecording()
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        if Int(event.keyCode) == kVK_Escape {
            finishRecording()
            return
        }

        if allowsClearing,
           Int(event.keyCode) == kVK_Delete || Int(event.keyCode) == kVK_ForwardDelete {
            shortcut = nil
            onChange?(nil)
            finishRecording()
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
        onChange?(newShortcut)
        finishRecording()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateColors()
        startRecordingOnAppearIfNeeded()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    func startRecordingOnAppearIfNeeded() {
        guard startsRecordingOnAppear, window != nil, !didStartRecordingOnAppear else {
            return
        }

        didStartRecordingOnAppear = true
        beginRecording()
    }

    func updateLabel() {
        label.stringValue = isRecording ? "Press Shortcut" : shortcut?.displayString ?? placeholder
        layer?.borderWidth = isRecording ? 1 : 0
        updateColors()
    }

    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            layer?.borderColor = NSColor.keyboardFocusIndicatorColor.cgColor
            label.textColor = shortcut == nil ? .secondaryLabelColor : .labelColor
        }
    }

    private func beginRecording() {
        isRecording = true
        window?.makeFirstResponder(self)
        updateLabel()
    }

    private func finishRecording() {
        let wasRecording = isRecording
        isRecording = false
        updateLabel()

        guard wasRecording else {
            return
        }

        DispatchQueue.main.async { [onRecordingEnded] in
            onRecordingEnded?()
        }
    }
}
