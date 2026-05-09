import Foundation

/// Collapses the three per-operation load states into a single UI state.
///
/// Ported from the KMP `resolveLazyPagingColumnState` helper so behaviour stays
/// in sync across platforms:
///
/// - a refresh failure surfaces as `.error`
/// - a finished refresh with zero items and both pagination ends reached is `.empty`
/// - a finished refresh with items is `.content`
/// - a finished refresh with no items and more pages still to load stays `.loading`
/// - during refresh reloads we preserve the previous state so the UI does not flash
public func resolveLazyPagingVStackState(
    refresh: LoadState,
    prepend: LoadState,
    append: LoadState,
    itemCount: Int,
    current: LazyPagingVStackState
) -> LazyPagingVStackState {
    switch refresh {
    case .failure(let error):
        return .error(error)

    case .notLoading:
        if prepend.endOfPaginationReached, append.endOfPaginationReached, itemCount == 0 {
            return .empty
        }
        if itemCount > 0 {
            return .content
        }
        return .loading

    case .loading:
        if case .loading = current { return .loading }
        return current
    }
}
