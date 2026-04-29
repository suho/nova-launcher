import AppKit
import Carbon
import SwiftUI

enum SearchMove {
    case up
    case down
}

struct CommandSearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onMove: (SearchMove) -> Void
    let onSubmit: () -> Void
    let onEscape: () -> Void

    func makeNSView(context: Context) -> SearchFieldHostView {
        let hostView = SearchFieldHostView()
        let textField = hostView.textField
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.drawsBackground = false
        textField.backgroundColor = .clear
        textField.focusRingType = .none
        textField.font = .systemFont(ofSize: 23, weight: .medium)
        textField.textColor = .labelColor
        textField.placeholderAttributedString = placeholderString
        textField.lineBreakMode = .byTruncatingTail
        textField.usesSingleLineMode = true
        textField.cell?.isScrollable = true
        textField.cell?.wraps = false
        context.coordinator.onMove = onMove
        context.coordinator.onSubmit = onSubmit
        context.coordinator.onEscape = onEscape

        return hostView
    }

    func updateNSView(_ nsView: SearchFieldHostView, context: Context) {
        let textField = nsView.textField

        if textField.stringValue != text {
            textField.stringValue = text
        }

        textField.placeholderAttributedString = placeholderString
        context.coordinator.onMove = onMove
        context.coordinator.onSubmit = onSubmit
        context.coordinator.onEscape = onEscape
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    private var placeholderString: NSAttributedString {
        NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: NSColor.placeholderTextColor,
                .font: NSFont.systemFont(ofSize: 23, weight: .medium)
            ]
        )
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding private var text: String
        var onMove: ((SearchMove) -> Void)?
        var onSubmit: (() -> Void)?
        var onEscape: (() -> Void)?

        init(text: Binding<String>) {
            _text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else {
                return
            }

            if let textView = textField.currentEditor() as? NSTextView {
                configureFieldEditor(textView)
            }

            text = textField.stringValue
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField,
                  let textView = textField.currentEditor() as? NSTextView else {
                return
            }

            configureFieldEditor(textView)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            configureFieldEditor(textView)

            switch commandSelector {
            case #selector(NSResponder.moveUp(_:)):
                onMove?(.up)
                return true
            case #selector(NSResponder.moveDown(_:)):
                onMove?(.down)
                return true
            case #selector(NSResponder.insertNewline(_:)):
                onSubmit?()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                onEscape?()
                return true
            default:
                return false
            }
        }

        private func configureFieldEditor(_ textView: NSTextView) {
            textView.drawsBackground = false
            textView.backgroundColor = .clear
            textView.insertionPointColor = .labelColor
        }
    }
}

final class SearchFieldHostView: NSView {
    let textField = KeyHandlingTextField()
    private var didRequestInitialFocus = false

    override var isOpaque: Bool {
        false
    }

    override var allowsVibrancy: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        textField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textField)

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 2),
            textField.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 38)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        guard window != nil, !didRequestInitialFocus else {
            return
        }

        didRequestInitialFocus = true

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            self.window?.makeFirstResponder(self.textField)
        }
    }
}

final class KeyHandlingTextField: NSTextField {
    override var isOpaque: Bool {
        false
    }

    override var allowsVibrancy: Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 36)
    }
}
