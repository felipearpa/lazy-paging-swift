import Testing
@testable import LazyPaging

@Suite("LazyPagingItems / maxSize page dropping")
@MainActor
struct LazyPagingItemsMaxSizeTests {
    private func makeItems(
        initialKey: Int = 0,
        maxSize: Int = 6
    ) -> LazyPagingItems<Int, TestItem> {
        let pager = Pager<Int, TestItem>(
            config: PagingConfig(pageSize: 3, prefetchDistance: 0, maxSize: maxSize),
            pagingSourceFactory: { NumberPagingSource(totalPages: 10, pageSize: 3) },
            initialKey: initialKey
        )
        return LazyPagingItems(pager: pager)
    }

    @Test("given maxSize exceeded by append when pages appended then head pages drop and itemsBefore bumps")
    func given_maxSizeExceededByAppend_when_pagesAppended_then_headPagesDropAndItemsBeforeBumps() async {
        let items = makeItems()
        await items.refresh()
        await items.appendIfNeeded(currentIndex: 2) // 6 items
        await items.appendIfNeeded(currentIndex: 5) // would be 9, drop first page

        #expect(items.loadedItems.map(\.id) == [3, 4, 5, 6, 7, 8])
        #expect(items.itemsBefore == 3)
    }

    @Test("given maxSize exceeded by prepend when pages prepended then tail pages drop and itemsAfter bumps")
    func given_maxSizeExceededByPrepend_when_pagesPrepended_then_tailPagesDropAndItemsAfterBumps() async {
        let items = makeItems(initialKey: 3)
        await items.refresh()
        await items.prependIfNeeded(currentIndex: 9)
        await items.prependIfNeeded(currentIndex: 6)

        #expect(items.loadedItems.map(\.id) == [3, 4, 5, 6, 7, 8])
        #expect(items.itemsAfter == 21)
    }

    @Test("given tail dropped by prepend when loadState is read then append EOP is cleared")
    func given_tailDroppedByPrepend_when_loadStateRead_then_appendEOPCleared() async {
        let items = makeItems(initialKey: 3)
        await items.refresh()
        await items.prependIfNeeded(currentIndex: 9)
        await items.prependIfNeeded(currentIndex: 6)
        #expect(!items.loadState.append.endOfPaginationReached)
    }
}
