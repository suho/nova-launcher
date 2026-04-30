import AppKit

@MainActor
enum AppearanceService {
    static func apply(_ theme: AppTheme) {
        NSApp.appearance = theme.nsAppearance
    }

    static func apply(rawValue: String) {
        apply(AppTheme(rawValue: rawValue) ?? .system)
    }
}
