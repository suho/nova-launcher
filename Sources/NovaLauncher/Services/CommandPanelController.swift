import AppKit
import SwiftUI

@MainActor
final class CommandPanelController: NSObject, NSWindowDelegate {
    private let store: LauncherStore
    private var panel: CommandPanel?

    init(store: LauncherStore) {
        self.store = store
        super.init()
    }

    func toggle() {
        if panel?.isVisible == true {
            close()
        } else {
            show()
        }
    }

    func show() {
        if let panel, panel.isVisible {
            present(panel)
            return
        }

        store.beginPaletteSession()

        let rootView = CommandPaletteView(
            store: store,
            dismiss: { [weak self] in self?.close() },
            onLayoutChange: { [weak self] isExpanded in
                self?.setPaletteExpanded(isExpanded, animated: false)
            }
        )

        let hostingView = NSHostingView(rootView: rootView)
        let initialSize = CommandPaletteMetrics.windowSize(isExpanded: false)
        hostingView.frame = NSRect(origin: .zero, size: initialSize)
        hostingView.autoresizingMask = [.width, .height]
        let panel = CommandPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.delegate = self
        panel.contentView = hostingView
        panel.setContentSize(initialSize)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true

        center(panel)

        self.panel = panel
        present(panel)
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    private func center(_ panel: NSPanel) {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero
        let panelFrame = panel.frame
        let origin = NSPoint(
            x: screenFrame.midX - panelFrame.width / 2,
            y: screenFrame.midY - panelFrame.height / 2 + 64
        )

        panel.setFrameOrigin(origin)
    }

    private func present(_ panel: NSPanel) {
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    private func setPaletteExpanded(_ isExpanded: Bool, animated: Bool) {
        guard let panel else {
            return
        }

        let targetSize = CommandPaletteMetrics.windowSize(isExpanded: isExpanded)
        let currentFrame = panel.frame
        let targetFrame = NSRect(
            x: currentFrame.midX - targetSize.width / 2,
            y: currentFrame.maxY - targetSize.height,
            width: targetSize.width,
            height: targetSize.height
        )

        guard currentFrame.size != targetSize else {
            return
        }

        panel.setFrame(targetFrame, display: true, animate: animated)
    }
}

final class CommandPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}
