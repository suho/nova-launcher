import AppKit
import SwiftUI

@MainActor
final class CommandPanelController: NSObject, NSWindowDelegate {
    private let store: LauncherStore
    private var panel: CommandPanel?
    private var sessionRefreshTask: Task<Void, Never>?
    var onOpenSettings: (() -> Void)?

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

        let panel = self.panel ?? makePanel()
        self.panel = panel
        setPaletteExpanded(false, animated: false)
        center(panel)
        present(panel)
        scheduleSessionRefresh(for: panel)
    }

    func close() {
        sessionRefreshTask?.cancel()
        sessionRefreshTask = nil
        panel?.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    private func makePanel() -> CommandPanel {
        let initialSize = CommandPaletteMetrics.windowSize(isExpanded: false)

        let rootView = CommandPaletteView(
            store: store,
            dismiss: { [weak self] in self?.close() },
            openSettings: { [weak self] in self?.openSettingsFromPanel() },
            onLayoutChange: { [weak self] isExpanded in
                self?.setPaletteExpanded(isExpanded, animated: false)
            }
        )

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: initialSize)
        hostingView.autoresizingMask = [.width, .height]
        let panel = CommandPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.delegate = self
        panel.onOpenSettings = { [weak self] in
            self?.openSettingsFromPanel()
        }
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

        return panel
    }

    private func center(_ panel: NSPanel) {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero
        let panelFrame = panel.frame
        let contentCenterOffset = CommandPaletteMetrics.contentCenterOffsetFromWindowTop(isExpanded: false)
        let desiredContentCenterY = screenFrame.midY + 64
        let origin = NSPoint(
            x: screenFrame.midX - panelFrame.width / 2,
            y: desiredContentCenterY - panelFrame.height + contentCenterOffset
        )

        panel.setFrameOrigin(origin)
    }

    private func present(_ panel: NSPanel) {
        panel.orderFrontRegardless()
        panel.makeKey()
        panel.displayIfNeeded()
    }

    private func openSettingsFromPanel() {
        close()
        onOpenSettings?()
    }

    private func scheduleSessionRefresh(for panel: NSPanel) {
        sessionRefreshTask?.cancel()
        sessionRefreshTask = Task { @MainActor [weak self, weak panel] in
            await Task.yield()

            guard !Task.isCancelled,
                  let self,
                  let panel,
                  self.panel === panel,
                  panel.isVisible else {
                return
            }

            self.store.refreshPaletteContext()
        }
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
    var onOpenSettings: (() -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.isCommandCommaShortcut {
            onOpenSettings?()
            return true
        }

        return super.performKeyEquivalent(with: event)
    }
}
