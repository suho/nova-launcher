import AppKit
import SwiftUI

@MainActor
final class ErrorToastWindowController {
    fileprivate enum Metrics {
        static let bottomInset: CGFloat = 56
        static let horizontalInset: CGFloat = 16
        static let minimumToastWidth: CGFloat = 188
        static let maximumToastWidth: CGFloat = 460
        static let toastHorizontalPadding: CGFloat = 28
        static let iconWidth: CGFloat = 14
        static let iconSpacing: CGFloat = 8
        static let textFont = NSFont.systemFont(ofSize: 12, weight: .medium)
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
        let screen = screenForToast()
        let toastWidth = toastWidth(for: message, on: screen)

        let content = ErrorToastWindowContent(message: message, toastWidth: toastWidth)
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
        let windowWidth = ErrorToastWindowContent.windowWidth(for: toastWidth)
        let windowSize = NSSize(
            width: windowWidth,
            height: max(fittingSize.height, ErrorToastWindowContent.minimumWindowHeight)
        )

        hostingView.frame = NSRect(origin: .zero, size: windowSize)
        panel.setContentSize(windowSize)
        panel.setFrame(NSRect(origin: origin(for: windowSize, on: screen), size: windowSize), display: true)
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

    private func toastWidth(for message: String, on screen: NSScreen?) -> CGFloat {
        let screenLimitedMaximum = screen.map { screen in
            max(
                Metrics.minimumToastWidth,
                screen.visibleFrame.width - Metrics.horizontalInset * 2 - ErrorToastWindowContent.shadowPadding * 2
            )
        } ?? Metrics.maximumToastWidth
        let maximumWidth = min(Metrics.maximumToastWidth, screenLimitedMaximum)
        let textSize = (message as NSString).boundingRect(
            with: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: Metrics.textFont]
        ).size
        let naturalWidth = ceil(textSize.width)
            + Metrics.iconWidth
            + Metrics.iconSpacing
            + Metrics.toastHorizontalPadding

        return min(max(naturalWidth, Metrics.minimumToastWidth), maximumWidth)
    }

    private func origin(for windowSize: NSSize, on screen: NSScreen?) -> NSPoint {
        guard let screen else {
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
    static let shadowPadding: CGFloat = 24
    static let minimumWindowHeight: CGFloat = 76
    static var minimumWindowSize: NSSize {
        NSSize(
            width: ErrorToastWindowController.Metrics.minimumToastWidth + shadowPadding * 2,
            height: minimumWindowHeight
        )
    }

    static func windowWidth(for toastWidth: CGFloat) -> CGFloat {
        toastWidth + shadowPadding * 2
    }

    let message: String
    let toastWidth: CGFloat

    var body: some View {
        ErrorToast(message: message, width: toastWidth)
            .padding(Self.shadowPadding)
            .frame(width: Self.windowWidth(for: toastWidth))
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
