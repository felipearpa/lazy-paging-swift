import Foundation

/// Wraps an inner ``PagingSource`` and injects separators between items
/// based on an async generator. Separators are also emitted at the edges
/// of each page (boundary with `nil` on one side), so the caller decides
/// whether a leading/trailing separator is appropriate.
///
/// Item counts change; `itemsBefore` / `itemsAfter` are zeroed out so the
/// indexing arithmetic in ``LazyPagingItems`` stays consistent.
final class SeparatingPagingSource<
    Key: Hashable & Sendable,
    Item: Sendable,
    Separator: Sendable
>: PagingSource<Key, SeparatedItem<Item, Separator>>, @unchecked Sendable {
    private let inner: PagingSource<Key, Item>
    private let generator: @Sendable (Item?, Item?) async -> Separator?

    init(
        inner: PagingSource<Key, Item>,
        generator: @escaping @Sendable (Item?, Item?) async -> Separator?
    ) {
        self.inner = inner
        self.generator = generator
        super.init()
        bridgeInvalidation()
    }

    override func load(
        loadConfig: LoadConfig<Key>
    ) async -> LoadResult<Key, SeparatedItem<Item, Separator>> {
        switch await inner.load(loadConfig: loadConfig) {
        case .page(let items, let previousKey, let nextKey, _, _):
            var separated: [SeparatedItem<Item, Separator>] = []
            separated.reserveCapacity(items.count * 2 + 1)

            if let leadingSeparator = await generator(nil, items.first) {
                separated.append(.separator(leadingSeparator))
            }

            for (index, item) in items.enumerated() {
                separated.append(.item(item))
                let next = index + 1 < items.count ? items[index + 1] : nil
                if let separator = await generator(item, next) {
                    separated.append(.separator(separator))
                }
            }

            return .page(
                items: separated,
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
