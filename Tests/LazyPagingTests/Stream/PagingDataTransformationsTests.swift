import Testing
@testable import LazyPaging

@Suite("PagingData transformations")
@MainActor
struct PagingDataTransformationsTests {
    private struct Separator: Identifiable, Hashable, Sendable {
        let id: Int
        let heading: String
    }

    private func makePager() -> Pager<Int, TestItem> {
        Pager<Int, TestItem>(
            config: PagingConfig(pageSize: 2),
            pagingSourceFactory: { NumberPagingSource(totalPages: 3, pageSize: 2) },
            initialKey: 0
        )
    }

    @Test("given map transformation when refreshed then items are transformed")
    func given_mapTransformation_when_refreshed_then_itemsAreTransformed() async {
        let mapped = makePager()
            .pagingData()
            .map { TestItem(id: $0.id, label: $0.label.uppercased() + "!") }
        let items = LazyPagingItems(pagingData: mapped)
        await items.refresh()
        #expect(items.loadedItems.map(\.label) == ["#0!", "#1!"])
    }

    @Test("given map transformation when refreshed then placeholder counts are preserved")
    func given_mapTransformation_when_refreshed_then_placeholderCountsPreserved() async {
        let mapped = makePager()
            .pagingData()
            .map { $0 }
        let items = LazyPagingItems(pagingData: mapped)
        await items.refresh()
        // NumberPagingSource reports itemsBefore=0, itemsAfter=4 at page 0.
        #expect(items.itemsAfter == 4)
    }

    @Test("given filter transformation when refreshed then non-matching items are dropped")
    func given_filterTransformation_when_refreshed_then_nonMatchingItemsDropped() async {
        let filtered = makePager()
            .pagingData()
            .filter { $0.id.isMultiple(of: 2) }
        let items = LazyPagingItems(pagingData: filtered)
        await items.refresh()
        #expect(items.loadedItems.map(\.id) == [0])
    }

    @Test("given filter transformation when refreshed then placeholder counts are zeroed")
    func given_filterTransformation_when_refreshed_then_placeholderCountsZeroed() async {
        let filtered = makePager()
            .pagingData()
            .filter { _ in true }
        let items = LazyPagingItems(pagingData: filtered)
        await items.refresh()
        #expect(items.itemsBefore == 0)
        #expect(items.itemsAfter == 0)
    }

    @Test("given insertSeparators when refreshed then leading separator is emitted")
    func given_insertSeparators_when_refreshed_then_leadingSeparatorEmitted() async {
        let separated = makePager()
            .pagingData()
            .insertSeparators { (before: TestItem?, after: TestItem?) -> Separator? in
                guard before == nil, let after else { return nil }
                return Separator(id: 1_000 + after.id, heading: "Start")
            }
        let items = LazyPagingItems(pagingData: separated)
        await items.refresh()

        guard case .separator(let separator) = items.loadedItems.first else {
            Issue.record("expected leading separator"); return
        }
        #expect(separator.heading == "Start")
    }

    @Test("given insertSeparators when refreshed then items remain interleaved with separators")
    func given_insertSeparators_when_refreshed_then_itemsRemainInterleaved() async {
        let separated = makePager()
            .pagingData()
            .insertSeparators { (before: TestItem?, after: TestItem?) -> Separator? in
                guard let before, let after else { return nil }
                return Separator(id: 1_000 + after.id, heading: "sep-\(before.id)-\(after.id)")
            }
        let items = LazyPagingItems(pagingData: separated)
        await items.refresh()

        // First page: items 0, 1 with one separator between them.
        let ids = items.loadedItems.compactMap { sep -> Int? in
            if case .item(let item) = sep { return item.id }
            return nil
        }
        #expect(ids == [0, 1])
        #expect(items.loadedItems.count == 3, "2 items + 1 separator")
    }
}
