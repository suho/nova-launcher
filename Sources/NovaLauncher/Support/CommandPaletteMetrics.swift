import CoreGraphics

enum CommandPaletteMetrics {
    static let contentWidth: CGFloat = 720
    static let searchBarHeight: CGFloat = 66
    static let panelSpacing: CGFloat = 8
    static let compactHeight: CGFloat = searchBarHeight
    static let expandedHeight: CGFloat = 448
    static let shadowHorizontalPadding: CGFloat = 112
    static let shadowTopPadding: CGFloat = 96
    static let shadowBottomPadding: CGFloat = 220

    static var resultsPanelHeight: CGFloat {
        expandedHeight - searchBarHeight - panelSpacing
    }

    static func contentHeight(isExpanded: Bool) -> CGFloat {
        isExpanded ? expandedHeight : compactHeight
    }

    static func contentCenterOffsetFromWindowTop(isExpanded: Bool) -> CGFloat {
        shadowTopPadding + contentHeight(isExpanded: isExpanded) / 2
    }

    static func windowSize(isExpanded: Bool) -> CGSize {
        CGSize(
            width: contentWidth + shadowHorizontalPadding * 2,
            height: contentHeight(isExpanded: isExpanded) + shadowTopPadding + shadowBottomPadding
        )
    }
}
