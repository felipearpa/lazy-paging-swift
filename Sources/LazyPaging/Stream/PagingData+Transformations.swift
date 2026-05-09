import Foundation

public extension PagingData {
    /// Returns a new ``PagingData`` whose items are the result of applying
    /// `transform` to each loaded item. Preserves placeholder counts
    /// (`itemsBefore` / `itemsAfter`) because mapping doesn't change how
    /// many items sit before or after the loaded window.
    func map<NewItem: Sendable>(
        _ transform: @escaping @Sendable (Item) async -> NewItem
    ) -> PagingData<Key, NewItem> {
        let wrapped = MappingPagingSource(inner: source, transform: transform)
        let newPager = Pager<Key, NewItem>(
            config: pager.config,
            pagingSourceFactory: { wrapped },
            initialKey: pager.initialKey
        )
        return PagingData<Key, NewItem>(pager: newPager, source: wrapped)
    }

    /// Returns a new ``PagingData`` that only emits items for which
    /// `predicate` returns `true`. Drops placeholder support — positions
    /// before and after the loaded window become `0` because filtering
    /// invalidates the original counts.
    func filter(
        _ predicate: @escaping @Sendable (Item) async -> Bool
    ) -> PagingData<Key, Item> {
        let wrapped = FilteringPagingSource(inner: source, predicate: predicate)
        let newPager = Pager<Key, Item>(
            config: pager.config,
            pagingSourceFactory: { wrapped },
            initialKey: pager.initialKey
        )
        return PagingData(pager: newPager, source: wrapped)
    }

    /// Returns a new ``PagingData`` with separators injected between (and
    /// optionally around) items. The generator receives `(before, after)`
    /// pairs — either may be `nil` at page boundaries — and returns a
    /// separator or `nil` to skip. The resulting ``SeparatedItem`` is
    /// `Identifiable` when both `Item` and `Separator` are (with matching
    /// `ID` types).
    ///
    /// Drops placeholder support for the same reason as ``filter(_:)``.
    func insertSeparators<Separator: Sendable>(
        _ generator: @escaping @Sendable (Item?, Item?) async -> Separator?
    ) -> PagingData<Key, SeparatedItem<Item, Separator>> {
        let wrapped = SeparatingPagingSource(inner: source, generator: generator)
        let newPager = Pager<Key, SeparatedItem<Item, Separator>>(
            config: pager.config,
            pagingSourceFactory: { wrapped },
            initialKey: pager.initialKey
        )
        return PagingData<Key, SeparatedItem<Item, Separator>>(pager: newPager, source: wrapped)
    }
}
