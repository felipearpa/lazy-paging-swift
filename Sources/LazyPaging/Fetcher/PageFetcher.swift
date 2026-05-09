import Foundation

/// Actor that owns the current ``PagingSource`` and the list of loaded
/// pages, and advances the cursors used to fetch neighbouring pages.
///
/// Being an actor makes cursor advancement serial-by-construction even when
/// refresh, prepend, and append races meet.
public actor PageFetcher<Key: Hashable & Sendable, Item: Sendable> {
    private let pager: Pager<Key, Item>
    private var pagingSource: PagingSource<Key, Item>
    private var loadedPages: [LoadedPage<Key, Item>] = []

    public init(pager: Pager<Key, Item>) {
        self.pager = pager
        self.pagingSource = pager.pagingSourceFactory()
    }

    /// Internal init that reuses a pre-built ``PagingSource`` (for example
    /// the one carried by a ``PagingData`` snapshot).
    init(pager: Pager<Key, Item>, source: PagingSource<Key, Item>) {
        self.pager = pager
        self.pagingSource = source
    }

    // MARK: Introspection

    public func pages() -> [LoadedPage<Key, Item>] { loadedPages }
    public func canPrepend() -> Bool { loadedPages.first?.previousKey != nil }
    public func canAppend() -> Bool { loadedPages.last?.nextKey != nil }

    // MARK: Loads

    public func refresh(anchorPosition: Int?, itemsBefore: Int) async -> FetchResult<Key, Item> {
        let state = PagingState<Key, Item>(
            pages: loadedPages,
            anchorPosition: anchorPosition,
            config: pager.config,
            leadingPlaceholderCount: itemsBefore
        )
        let refreshKey = pagingSource.getRefreshKey(state: state) ?? pager.initialKey

        loadedPages = []
        let result = await pagingSource.load(
            loadConfig: LoadConfig(
                key: refreshKey,
                kind: .refresh,
                loadSize: pager.config.initialLoadSize
            )
        )
        return handle(result: result, kind: .refresh)
    }

    public func prepend() async -> FetchResult<Key, Item>? {
        guard let key = loadedPages.first?.previousKey else { return nil }
        let result = await pagingSource.load(
            loadConfig: LoadConfig(key: key, kind: .prepend, loadSize: pager.config.pageSize)
        )
        return handle(result: result, kind: .prepend)
    }

    public func append() async -> FetchResult<Key, Item>? {
        guard let key = loadedPages.last?.nextKey else { return nil }
        let result = await pagingSource.load(
            loadConfig: LoadConfig(key: key, kind: .append, loadSize: pager.config.pageSize)
        )
        return handle(result: result, kind: .append)
    }

    // MARK: Invalidation

    func registerInvalidateAction(_ action: @escaping InvalidateAction) async -> UUID {
        await pagingSource.registerInvalidateAction(action)
    }

    func unregisterInvalidateAction(id: UUID) async {
        await pagingSource.unregisterInvalidateAction(id: id)
    }

    // MARK: Private

    private func handle(
        result: LoadResult<Key, Item>,
        kind: LoadConfig<Key>.Kind
    ) -> FetchResult<Key, Item> {
        switch result {
        case .page(let items, let newPrevious, let newNext, let itemsBefore, let itemsAfter):
            let page = LoadedPage(items: items, previousKey: newPrevious, nextKey: newNext)
            switch kind {
            case .refresh:
                loadedPages = [page]
            case .prepend:
                loadedPages.insert(page, at: 0)
            case .append:
                loadedPages.append(page)
            }

            let dropped = applyMaxSizeDropIfNeeded(oppositeOf: kind)

            return .page(
                items: items,
                previousKey: newPrevious,
                nextKey: newNext,
                itemsBefore: itemsBefore,
                itemsAfter: itemsAfter,
                droppedFromHead: dropped.head,
                droppedFromTail: dropped.tail
            )
        case .failure(let error):
            return .failure(error)
        case .invalid:
            return .invalid
        }
    }

    /// After a successful append, drop pages from the head if we're over the
    /// configured `maxSize`. Symmetric for prepend. Returns the counts so
    /// ``LazyPagingItems`` can bump its `itemsBefore` / `itemsAfter`.
    private func applyMaxSizeDropIfNeeded(
        oppositeOf kind: LoadConfig<Key>.Kind
    ) -> (head: Int, tail: Int) {
        guard let maxSize = pager.config.maxSize else { return (0, 0) }
        var totalItems = loadedPages.reduce(0) { $0 + $1.items.count }
        guard totalItems > maxSize else { return (0, 0) }

        var droppedFromHead = 0
        var droppedFromTail = 0

        switch kind {
        case .append:
            // Drop pages from the head until we're at or below maxSize, but
            // never so deep that we drop our own freshly appended page.
            while totalItems > maxSize, loadedPages.count > 1 {
                let removed = loadedPages.removeFirst()
                droppedFromHead += removed.items.count
                totalItems -= removed.items.count
            }
        case .prepend:
            while totalItems > maxSize, loadedPages.count > 1 {
                let removed = loadedPages.removeLast()
                droppedFromTail += removed.items.count
                totalItems -= removed.items.count
            }
        case .refresh:
            // Refresh starts from a single page; nothing to drop.
            break
        }

        return (droppedFromHead, droppedFromTail)
    }
}

/// One contiguous chunk of loaded items plus the keys used to fetch the
/// pages immediately before and after it.
public struct LoadedPage<Key: Sendable, Item: Sendable>: Sendable {
    public let items: [Item]
    public let previousKey: Key?
    public let nextKey: Key?

    public init(items: [Item], previousKey: Key?, nextKey: Key?) {
        self.items = items
        self.previousKey = previousKey
        self.nextKey = nextKey
    }
}

/// Normalised output of a ``PageFetcher`` operation.
public enum FetchResult<Key: Sendable, Item: Sendable>: Sendable {
    case page(
        items: [Item],
        previousKey: Key?,
        nextKey: Key?,
        itemsBefore: Int,
        itemsAfter: Int,
        droppedFromHead: Int,
        droppedFromTail: Int
    )
    case failure(any Error & Sendable)
    case invalid
}
