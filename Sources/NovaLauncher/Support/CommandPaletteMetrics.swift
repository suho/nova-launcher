import CoreGraphics

enum CommandPaletteMetrics {
    static let contentWidth: CGFloat = 720
    static let searchBarHeight: CGFloat = 66
    static let panelSpacing: CGFloat = 8
    static let compactHeight: CGFloat = searchBarHeight
    static let expandedHeight: CGFloat = 448
    static let shadowPadding: CGFloat = 96

    static var resultsPanelHeight: CGFloat {
        expandedHeight - searchBarHeight - panelSpacing
    }

    static func contentHeight(isExpanded: Bool) -> CGFloat {
        isExpanded ? expandedHeight : compactHeight
    }

    static func windowSize(isExpanded: Bool) -> CGSize {
        CGSize(
            width: contentWidth + shadowPadding * 2,
            height: contentHeight(isExpanded: isExpanded) + shadowPadding * 2
        )
    }
}
