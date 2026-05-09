import Foundation

/// Which direction a paging operation is running in — the argument
/// ``RemoteMediator/load(loadType:state:)`` receives.
public enum LoadType: Sendable, Equatable {
    case refresh
    case prepend
    case append
}
