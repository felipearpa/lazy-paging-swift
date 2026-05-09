import Foundation

/// High-level UI state of a paginated lazy column.
///
/// Mirrors the KMP `LazyPagingColumnState` sealed interface: the resolver
/// collapses the three paging load states into the single state the UI needs
/// to render, so call-sites only write per-state content slots.
public enum LazyPagingVStackState: Sendable {
    case loading
    case empty
    case error(any Error & Sendable)
    case content
}

public extension LazyPagingVStackState {
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }

    var isError: Bool {
        if case .error = self { return true }
        return false
    }

    var isContent: Bool {
        if case .content = self { return true }
        return false
    }

    var error: (any Error)? {
        if case .error(let error) = self { return error }
        return nil
    }
}
