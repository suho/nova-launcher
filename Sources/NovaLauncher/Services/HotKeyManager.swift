import Carbon
import Foundation

@MainActor
final class HotKeyManager: ObservableObject {
    @Published private(set) var statusMessage = "Ready"
    @Published private(set) var itemStatusMessage = "No item shortcuts configured"

    var onPressed: (() -> Void)?

    private let hotKeySignature = fourCharacterCode("NOVA")
    private let launcherActionID: UInt32 = 1
    private let itemActionIDBase: UInt32 = 1_000
    private var launcherEventHotKey: EventHotKeyRef?
    private var itemEventHotKeys: [UInt32: EventHotKeyRef] = [:]
    private var actions: [UInt32: () -> Void] = [:]
    private var eventHandler: EventHandlerRef?

    func start() {
        installHandlerIfNeeded()
        register(KeyboardShortcut.fromDefaults())
    }

    func updateShortcut(_ shortcut: KeyboardShortcut) {
        shortcut.save()
        register(shortcut)
    }

    func updateItemShortcuts(_ registrations: [ItemHotKeyRegistration]) {
        unregisterItemHotKeys()

        guard !registrations.isEmpty else {
            itemStatusMessage = "No item shortcuts configured"
            return
        }

        var registeredCount = 0

        for (offset, registration) in registrations.enumerated() {
            let actionID = itemActionIDBase + UInt32(offset)
            var newHotKey: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: actionID)
            let status = RegisterEventHotKey(
                registration.shortcut.keyCode,
                registration.shortcut.modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &newHotKey
            )

            if status == noErr, let newHotKey {
                itemEventHotKeys[actionID] = newHotKey
                actions[actionID] = registration.action
                registeredCount += 1
            }
        }

        if registeredCount == registrations.count {
            itemStatusMessage = "\(registeredCount) item shortcut\(registeredCount == 1 ? "" : "s") ready"
        } else {
            itemStatusMessage = "\(registeredCount) of \(registrations.count) item shortcuts ready"
        }
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

                if incomingHotKeyID.signature == manager.hotKeySignature,
                   let action = manager.actions[incomingHotKeyID.id] {
                    Task { @MainActor in
                        action()
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
        unregisterLauncherHotKey()

        var newHotKey: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: launcherActionID)
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &newHotKey
        )

        if status == noErr, let newHotKey {
            launcherEventHotKey = newHotKey
            actions[launcherActionID] = { [weak self] in
                self?.onPressed?()
            }
            statusMessage = "\(shortcut.displayString) ready"
        } else {
            actions.removeValue(forKey: launcherActionID)
            statusMessage = "Shortcut unavailable"
        }
    }

    private func unregisterLauncherHotKey() {
        if let launcherEventHotKey {
            UnregisterEventHotKey(launcherEventHotKey)
            self.launcherEventHotKey = nil
        }

        actions.removeValue(forKey: launcherActionID)
    }

    private func unregisterItemHotKeys() {
        for eventHotKey in itemEventHotKeys.values {
            UnregisterEventHotKey(eventHotKey)
        }

        for actionID in itemEventHotKeys.keys {
            actions.removeValue(forKey: actionID)
        }

        itemEventHotKeys.removeAll()
    }
}

struct ItemHotKeyRegistration {
    let id: String
    let shortcut: KeyboardShortcut
    let action: () -> Void
}
