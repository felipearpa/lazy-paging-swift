import Foundation

/// Abstract source of pages. Subclass to provide a concrete loading strategy.
///
/// `PagingSource` is thread-safe by construction: load operations are
/// serialised through Swift concurrency and invalidation callbacks are
/// managed by an actor. Subclasses must implement ``load(loadConfig:)``,
/// may override ``getRefreshKey(state:)`` to preserve scroll position on
/// refresh, and may call ``invalidate()`` to signal that the current data
/// set is stale.
open class PagingSource<Key: Hashable & Sendable, Item: Sendable>: @unchecked Sendable {
    private let invalidateActionTracker = InvalidateActionTracker()

    public init() {}

    /// Loads a single page of data for the given ``LoadConfig``.
    ///
    /// Subclasses **must** override this method. The default implementation
    /// traps so unintended calls surface immediately.
    open func load(loadConfig: LoadConfig<Key>) async -> LoadResult<Key, Item> {
        fatalError("PagingSource.load(loadConfig:) must be overridden by subclasses")
    }

    /// Picks a refresh key that preserves the user's scroll position. The
    /// default implementation returns `nil`, which causes the pager to fall
    /// back to ``Pager/initialKey``. Override this to compute a key near the
    /// current anchor — for example, from the previous/next keys of the page
    /// closest to the anchor.
    open func getRefreshKey(state: PagingState<Key, Item>) -> Key? {
        return nil
    }

    /// Notifies every registered observer that the source's data is stale.
    ///
    /// Callers typically react by triggering a refresh of the owning
    /// ``LazyPagingItems``.
    public func invalidate() {
        Task { [invalidateActionTracker] in
            await invalidateActionTracker.invalidate()
        }
    }

    // MARK: Internal invalidation wiring

    func registerInvalidateAction(_ action: @escaping InvalidateAction) async -> UUID {
        await invalidateActionTracker.register(action)
    }

    func unregisterInvalidateAction(id: UUID) async {
        await invalidateActionTracker.unregister(id: id)
    }
}
