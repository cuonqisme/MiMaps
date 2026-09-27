import Foundation

enum NavigationState: Sendable, Equatable {
    case idle
    case requestingPermissions
    case searching
    case calculatingRoute
    case routePreview
    case startingNavigation
    case navigating
    case rerouting
    case arrived
    case stopped
    case error(String)
}

