import AppKit
import SwiftUI

@MainActor
final class ErrorToastWindowController {
    private enum Metrics {
        static let bottomInset: CGFloat = 56
        static let horizontalInset: CGFloat = 16
    }

    private var panel: ErrorToastPanel?
    private var hostingView: NSHostingView<ErrorToastWindowContent>?

    func update(message: String?) {
        guard let message, !message.isEmpty else {
            hide()
            return
        }

        show(message: message)
    }

    private func show(message: String) {
        let panel = self.panel ?? makePanel()
        self.panel = panel

        let content = ErrorToastWindowContent(message: message)
        let hostingView: NSHostingView<ErrorToastWindowContent>

        if let existingHostingView = self.hostingView {
            existingHostingView.rootView = content
            hostingView = existingHostingView
        } else {
            let newHostingView = NSHostingView(rootView: content)
            newHostingView.frame = NSRect(origin: .zero, size: ErrorToastWindowContent.minimumWindowSize)
            newHostingView.autoresizingMask = [.width, .height]
            panel.contentView = newHostingView
            self.hostingView = newHostingView
            hostingView = newHostingView
        }

        hostingView.invalidateIntrinsicContentSize()
        let fittingSize = hostingView.fittingSize
        let windowSize = NSSize(
            width: ErrorToastWindowContent.windowWidth,
            height: max(fittingSize.height, ErrorToastWindowContent.minimumWindowHeight)
        )

        hostingView.frame = NSRect(origin: .zero, size: windowSize)
        panel.setContentSize(windowSize)
        panel.setFrame(NSRect(origin: origin(for: windowSize), size: windowSize), display: true)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
    }

    private func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> ErrorToastPanel {
        let panel = ErrorToastPanel(
            contentRect: NSRect(origin: .zero, size: ErrorToastWindowContent.minimumWindowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = true
        panel.animationBehavior = .none
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        return panel
    }

    private func origin(for windowSize: NSSize) -> NSPoint {
        guard let screen = screenForToast() else {
            return .zero
        }

        let frame = screen.visibleFrame
        let minimumX = frame.minX + Metrics.horizontalInset
        let maximumX = max(minimumX, frame.maxX - Metrics.horizontalInset - windowSize.width)
        let centeredX = frame.midX - windowSize.width / 2
        let x = min(max(centeredX, minimumX), maximumX)
        let y = frame.minY + Metrics.bottomInset

        return NSPoint(x: x.rounded(), y: y.rounded())
    }

    private func screenForToast() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation

        return NSScreen.screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        } ?? NSScreen.main ?? NSScreen.screens.first
    }
}

private struct ErrorToastWindowContent: View {
    static let toastWidth: CGFloat = 340
    static let shadowPadding: CGFloat = 24
    static let minimumWindowHeight: CGFloat = 76
    static var windowWidth: CGFloat { toastWidth + shadowPadding * 2 }
    static var minimumWindowSize: NSSize {
        NSSize(width: windowWidth, height: minimumWindowHeight)
    }

    let message: String

    var body: some View {
        ErrorToast(message: message)
            .padding(Self.shadowPadding)
            .frame(width: Self.windowWidth)
    }
}

private final class ErrorToastPanel: NSPanel {
    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}
