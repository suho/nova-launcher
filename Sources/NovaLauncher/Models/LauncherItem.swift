import Foundation

enum LauncherItem: Identifiable, Hashable, FuzzySearchable {
    case application(ApplicationEntry)
    case windowCommand(WindowCommand)
    case webURL(WebURLItem)

    var id: String {
        switch self {
        case .application(let application):
            "app:\(application.id)"
        case .windowCommand(let command):
            "window:\(command.id)"
        case .webURL(let webURL):
            "url:\(webURL.id)"
        }
    }

    var title: String {
        switch self {
        case .application(let application):
            application.name
        case .windowCommand(let command):
            command.title
        case .webURL:
            "Open URL"
        }
    }

    var subtitle: String {
        switch self {
        case .application(let application):
            application.subtitle
        case .windowCommand(let command):
            command.defaultSubtitle
        case .webURL(let webURL):
            webURL.displayString
        }
    }

    var sortName: String {
        title
    }

    var searchableName: String {
        switch self {
        case .application(let application):
            application.searchableName
        case .windowCommand(let command):
            command.searchableName
        case .webURL(let webURL):
            webURL.displayString.lowercased()
        }
    }

    var searchCharacters: [Character] {
        switch self {
        case .application(let application):
            application.searchCharacters
        case .windowCommand, .webURL:
            Array(searchableName)
        }
    }
}

enum WindowCommand: String, CaseIterable, Identifiable, Hashable {
    case leftHalf
    case rightHalf
    case maximize
    case nextDesktop

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .leftHalf:
            "Window: Left Half"
        case .rightHalf:
            "Window: Right Half"
        case .maximize:
            "Window: Maximize"
        case .nextDesktop:
            "Window: Next Desktop"
        }
    }

    var defaultSubtitle: String {
        switch self {
        case .leftHalf:
            "Resize the focused window to the left half"
        case .rightHalf:
            "Resize the focused window to the right half"
        case .maximize:
            "Maximize the focused window"
        case .nextDesktop:
            "Move the focused window to the next display"
        }
    }

    var systemImage: String {
        switch self {
        case .leftHalf:
            "rectangle.leadinghalf.inset.filled"
        case .rightHalf:
            "rectangle.trailinghalf.inset.filled"
        case .maximize:
            "arrow.up.left.and.arrow.down.right"
        case .nextDesktop:
            "rectangle.portrait.and.arrow.right"
        }
    }

    var searchableName: String {
        switch self {
        case .leftHalf:
            "window left half set left snap left tile left move left"
        case .rightHalf:
            "window right half set right snap right tile right move right"
        case .maximize:
            "window maximize max full screen fill zoom"
        case .nextDesktop:
            "window next display monitor desktop move next space send next desktop"
        }
    }
}
