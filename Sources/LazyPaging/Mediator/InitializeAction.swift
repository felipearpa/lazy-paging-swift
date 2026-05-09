import Foundation

/// What ``RemoteMediator/initialize()`` tells the pager to do on the
/// first refresh.
///
/// - `launchInitialRefresh` — the pager will call `load(.refresh, state:)`
///   on the mediator before reading from the local ``PagingSource``.
/// - `skipInitialRefresh` — the pager skips the mediator on initial
///   refresh and reads straight from the local source; useful when the
///   local store is known to be fresh.
public enum InitializeAction: Sendable, Equatable {
    case launchInitialRefresh
    case skipInitialRefresh
}
