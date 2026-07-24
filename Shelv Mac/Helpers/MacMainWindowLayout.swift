import CoreGraphics

enum MacMainWindowLayout {
    static let windowMinimumHeight: CGFloat = 600
    static let windowMinimumWidth: CGFloat = windowMinimumHeight * 16 / 9
    static let sidebarMinimumWidth: CGFloat = 190
    static let sidebarPreferredWidth: CGFloat = 235
    static let sidebarMaximumWidth: CGFloat = 310
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

    static func navigationWidth(for availableWidth: CGFloat, showsSidePanel: Bool) -> CGFloat {
        guard showsSidePanel else { return availableWidth }
        return availableWidth - sidePanelWidth(for: availableWidth) - dividerWidth
    }

    static func sidebarMaximumWidth(for navigationWidth: CGFloat) -> CGFloat {
        min(
            sidebarMaximumWidth,
            max(sidebarMinimumWidth, navigationWidth - contentMinimumWidth)
        )
    }
}
