import Foundation

/// One paging session: a ``PagingSource`` instance plus the config and
/// initial key used to drive it.
///
/// Analogous to AndroidX's `PagingData<T>` — a unit of work that a
/// consumer (typically ``LazyPagingItems``) collects once. Transformations
/// (``map(_:)``, ``filter(_:)``, ``insertSeparators(_:)``) return new
/// `PagingData` snapshots backed by wrapping sources, so the transforms
/// compose without reaching into the underlying pager.
public struct PagingData<Key: Hashable & Sendable, Item: Sendable>: Sendable {
    let pager: Pager<Key, Item>
    let source: PagingSource<Key, Item>

    init(pager: Pager<Key, Item>, source: PagingSource<Key, Item>) {
        self.pager = pager
        self.source = source
    }
}
