import CoreGraphics

enum MacMainWindowLayout {
    static let sidebarMinimumWidth: CGFloat = 190
    static let contentMinimumWidth: CGFloat = 550
    static let sidePanelPreferredWidth: CGFloat = 410
    static let sidePanelMinimumWidth: CGFloat = 250
    static let filterFieldVisibilityWidth: CGFloat = 700
    static let dividerWidth: CGFloat = 1

    static var navigationMinimumWidth: CGFloat {
        sidebarMinimumWidth + contentMinimumWidth
    }

    static func sidePanelWidth(for availableWidth: CGFloat) -> CGFloat {
        let availablePanelWidth = availableWidth - navigationMinimumWidth - dividerWidth
        return min(
            sidePanelPreferredWidth,
            max(sidePanelMinimumWidth, availablePanelWidth)
        )
    }
}
