import Foundation

/// Wraps an inner ``PagingSource`` and drops items that don't satisfy the
/// predicate. Filtering changes item counts per page, so the wrapped
/// source zeroes out `itemsBefore` / `itemsAfter` — placeholders don't
/// survive filtering.
final class FilteringPagingSource<
    Key: Hashable & Sendable,
    Item: Sendable
>: PagingSource<Key, Item>, @unchecked Sendable {
    private let inner: PagingSource<Key, Item>
    private let predicate: @Sendable (Item) async -> Bool

    init(
        inner: PagingSource<Key, Item>,
        predicate: @escaping @Sendable (Item) async -> Bool
    ) {
        self.inner = inner
        self.predicate = predicate
        super.init()
        bridgeInvalidation()
    }

    override func load(loadConfig: LoadConfig<Key>) async -> LoadResult<Key, Item> {
        switch await inner.load(loadConfig: loadConfig) {
        case .page(let items, let previousKey, let nextKey, _, _):
            var filtered: [Item] = []
            filtered.reserveCapacity(items.count)
            for item in items where await predicate(item) {
                filtered.append(item)
            }
            return .page(
                items: filtered,
                previousKey: previousKey,
                nextKey: nextKey,
                itemsBefore: 0,
                itemsAfter: 0
            )
        case .failure(let error):
            return .failure(error)
        case .invalid:
            return .invalid
        }
    }

    private func bridgeInvalidation() {
        let inner = self.inner
        Task { [weak self] in
            _ = await inner.registerInvalidateAction { [weak self] in
                self?.invalidate()
            }
        }
    }
}
