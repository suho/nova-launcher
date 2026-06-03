import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case items
    case appearance
    case privacy

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .general:
            "General"
        case .items:
            "Items"
        case .appearance:
            "Appearance"
        case .privacy:
            "Privacy"
        }
    }

    var subtitle: String {
        switch self {
        case .general:
            "Startup, shortcut, indexing, and ranking."
        case .items:
            "Configure apps, commands, and custom hotkeys."
        case .appearance:
            "Choose how Nova follows macOS."
        case .privacy:
            "Review local indexing and required permissions."
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            "gearshape"
        case .items:
            "list.bullet.rectangle"
        case .appearance:
            "paintpalette"
        case .privacy:
            "lock.shield"
        }
    }
}
