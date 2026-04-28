import Carbon
import Foundation

@MainActor
final class HotKeyManager: ObservableObject {
    @Published private(set) var statusMessage = "Ready"

    var onPressed: (() -> Void)?

    private var eventHotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: fourCharacterCode("NOVA"), id: 1)

    func start() {
        installHandlerIfNeeded()
        register(KeyboardShortcut.fromDefaults())
    }

    func updateShortcut(_ shortcut: KeyboardShortcut) {
        shortcut.save()
        register(shortcut)
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else {
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event,
                      let userData else {
                    return noErr
                }

                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                var incomingHotKeyID = EventHotKeyID()

                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &incomingHotKeyID
                )

                if incomingHotKeyID.signature == manager.hotKeyID.signature,
                   incomingHotKeyID.id == manager.hotKeyID.id {
                    Task { @MainActor in
                        manager.onPressed?()
                    }
                }

                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        if status != noErr {
            statusMessage = "Could not install hotkey handler"
        }
    }

    private func register(_ shortcut: KeyboardShortcut) {
        unregister()

        var newHotKey: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &newHotKey
        )

        if status == noErr, let newHotKey {
            eventHotKey = newHotKey
            statusMessage = "\(shortcut.displayString) ready"
        } else {
            statusMessage = "Shortcut unavailable"
        }
    }

    private func unregister() {
        if let eventHotKey {
            UnregisterEventHotKey(eventHotKey)
            self.eventHotKey = nil
        }
    }
}
