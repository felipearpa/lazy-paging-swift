import Foundation

/// Snapshot of the currently loaded pages handed to
/// ``PagingSource/getRefreshKey(state:)`` so the source can pick a refresh
/// key that preserves the user's scroll position.
///
/// Mirrors AndroidX Paging's `PagingState`: carries the loaded pages, the
/// user's last anchor (the index they were looking at), and the page config.
public struct PagingState<Key: Hashable & Sendable, Item: Sendable>: Sendable {
    public let pages: [LoadedPage<Key, Item>]
    public let anchorPosition: Int?
    public let config: PagingConfig
    public let leadingPlaceholderCount: Int

    public init(
        pages: [LoadedPage<Key, Item>],
        anchorPosition: Int?,
        config: PagingConfig,
        leadingPlaceholderCount: Int
    ) {
        self.pages = pages
        self.anchorPosition = anchorPosition
        self.config = config
        self.leadingPlaceholderCount = leadingPlaceholderCount
    }

    /// Returns the loaded page that contains (or is closest to) the given
    /// anchor position. `anchorPosition` is expressed in the same index
    /// space as ``LazyPagingItems/subscript(_:)`` — i.e. it includes leading
    /// placeholders.
    public func closestPageToPosition(_ anchorPosition: Int) -> LoadedPage<Key, Item>? {
        guard !pages.isEmpty else { return nil }
        var cursor = leadingPlaceholderCount
        var lastNonEmpty: LoadedPage<Key, Item>?
        for page in pages {
            let pageStart = cursor
            let pageEnd = cursor + page.items.count
            if page.items.isEmpty {
                cursor = pageEnd
                continue
            }
            if anchorPosition < pageStart {
                return lastNonEmpty ?? page
            }
            if anchorPosition < pageEnd {
                return page
            }
            lastNonEmpty = page
            cursor = pageEnd
        }
        return lastNonEmpty
    }

    /// Returns the item at the given anchor position if it has been loaded.
    public func closestItemToPosition(_ anchorPosition: Int) -> Item? {
        guard !pages.isEmpty else { return nil }
        var cursor = leadingPlaceholderCount
        for page in pages {
            let pageStart = cursor
            let pageEnd = cursor + page.items.count
            if page.items.isEmpty { continue }
            if anchorPosition < pageStart { return page.items.first }
            if anchorPosition < pageEnd { return page.items[anchorPosition - pageStart] }
            cursor = pageEnd
        }
        return pages.last(where: { !$0.items.isEmpty })?.items.last
    }

    /// Flat list of every item currently loaded, across every page.
    public var items: [Item] { pages.flatMap(\.items) }

    /// Whether every loaded page is empty (or there are no pages).
    public var isEmpty: Bool { items.isEmpty }
}
