import Foundation

/// A triple of load states for one end-to-end layer (either the
/// ``PagingSource`` or a ``RemoteMediator``).
public struct LoadStates: Sendable, Equatable {
    public let refresh: LoadState
    public let prepend: LoadState
    public let append: LoadState

    public init(refresh: LoadState, prepend: LoadState, append: LoadState) {
        self.refresh = refresh
        self.prepend = prepend
        self.append = append
    }

    public static let idle = LoadStates(
        refresh: .notLoading(endOfPaginationReached: false),
        prepend: .notLoading(endOfPaginationReached: false),
        append: .notLoading(endOfPaginationReached: false)
    )
}

/// Aggregated load states for the three paging operations exposed to the UI.
///
/// The top-level ``refresh`` / ``prepend`` / ``append`` are the combined
/// view across the optional ``source`` and ``mediator`` layers — they
/// reflect whichever layer is currently loading, failing, or idle. When a
/// ``RemoteMediator`` is not in use, only ``source`` is populated (and it
/// matches the top-level triple exactly).
public struct CombinedLoadStates: Sendable, Equatable {
    public let refresh: LoadState
    public let prepend: LoadState
    public let append: LoadState
    public let source: LoadStates?
    public let mediator: LoadStates?

    public init(
        refresh: LoadState,
        prepend: LoadState,
        append: LoadState,
        source: LoadStates? = nil,
        mediator: LoadStates? = nil
    ) {
        self.refresh = refresh
        self.prepend = prepend
        self.append = append
        self.source = source
        self.mediator = mediator
    }
}

public extension CombinedLoadStates {
    static let idle = CombinedLoadStates(
        refresh: .notLoading(endOfPaginationReached: false),
        prepend: .notLoading(endOfPaginationReached: false),
        append: .notLoading(endOfPaginationReached: false),
        source: .idle,
        mediator: nil
    )

    /// Combines two load states into the "most active" — failure wins over
    /// loading, loading wins over idle. Used to fold mediator + source
    /// states into the top-level triple.
    static func combine(_ lhs: LoadState, _ rhs: LoadState) -> LoadState {
        if case .failure = lhs { return lhs }
        if case .failure = rhs { return rhs }
        if case .loading = lhs { return lhs }
        if case .loading = rhs { return rhs }
        // Both notLoading — prefer the end-of-pagination flag from the
        // source side, which is the authoritative "no more items" signal.
        return lhs
    }
}
