import Foundation

/// Wraps an inner ``PagingSource`` and applies an async transform to every
/// loaded item. Preserves keys and placeholder counts — item count per
/// page is unchanged, so `itemsBefore`/`itemsAfter` remain valid.
///
/// Invalidation is bridged in both directions so `inner.invalidate()` and
/// `self.invalidate()` fire both trackers.
final class MappingPagingSource<
    Key: Hashable & Sendable,
    Input: Sendable,
    Output: Sendable
>: PagingSource<Key, Output>, @unchecked Sendable {
    private let inner: PagingSource<Key, Input>
    private let transform: @Sendable (Input) async -> Output

    init(
        inner: PagingSource<Key, Input>,
        transform: @escaping @Sendable (Input) async -> Output
    ) {
        self.inner = inner
        self.transform = transform
        super.init()
        bridgeInvalidation()
    }

    override func load(loadConfig: LoadConfig<Key>) async -> LoadResult<Key, Output> {
        switch await inner.load(loadConfig: loadConfig) {
        case .page(let items, let previousKey, let nextKey, let itemsBefore, let itemsAfter):
            var mapped: [Output] = []
            mapped.reserveCapacity(items.count)
            for item in items {
                mapped.append(await transform(item))
            }
            return .page(
                items: mapped,
                previousKey: previousKey,
                nextKey: nextKey,
                itemsBefore: itemsBefore,
                itemsAfter: itemsAfter
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
