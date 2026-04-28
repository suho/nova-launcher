import Foundation

enum LauncherItem: Identifiable, Hashable, FuzzySearchable {
    case application(ApplicationEntry)
    case windowCommand(WindowCommand)

    var id: String {
        switch self {
        case .application(let application):
            "app:\(application.id)"
        case .windowCommand(let command):
            "window:\(command.id)"
        }
    }

    var title: String {
        switch self {
        case .application(let application):
            application.name
        case .windowCommand(let command):
            command.title
        }
    }

    var subtitle: String {
        switch self {
        case .application(let application):
            application.subtitle
        case .windowCommand(let command):
            command.defaultSubtitle
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
        }
    }

    var searchCharacters: [Character] {
        switch self {
        case .application(let application):
            application.searchCharacters
        case .windowCommand:
            Array(searchableName)
        }
    }
}

enum WindowCommand: String, CaseIterable, Identifiable, Hashable {
    case leftHalf
    case rightHalf
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
        case .nextDesktop:
            "Move the focused window to the next desktop"
        }
    }

    var systemImage: String {
        switch self {
        case .leftHalf:
            "rectangle.leadinghalf.inset.filled"
        case .rightHalf:
            "rectangle.trailinghalf.inset.filled"
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
        case .nextDesktop:
            "window next desktop move next space send next desktop"
        }
    }
}
