import Testing
@testable import LazyPaging

@Suite("LazyPagingItems / subscript + peek + itemCount")
@MainActor
struct LazyPagingItemsSubscriptTests {
    private func makeItems(
        totalPages: Int = 5,
        pageSize: Int = 2,
        initialKey: Int = 0,
        reportsPlaceholders: Bool = true
    ) -> LazyPagingItems<Int, TestItem> {
        let pager = Pager<Int, TestItem>(
            config: PagingConfig(pageSize: pageSize),
            pagingSourceFactory: {
                NumberPagingSource(
                    totalPages: totalPages,
                    pageSize: pageSize,
                    reportsPlaceholders: reportsPlaceholders
                )
            },
            initialKey: initialKey
        )
        return LazyPagingItems(pager: pager)
    }

    @Test("given placeholders reported when refreshed then itemCount covers full range")
    func given_placeholdersReported_when_refreshed_then_itemCountCoversFullRange() async {
        let items = makeItems()
        await items.refresh()
        #expect(items.itemCount == 10)
    }

    @Test("given refreshed items when subscript loaded index then returns item")
    func given_refreshedItems_when_subscriptLoadedIndex_then_returnsItem() async {
        let items = makeItems()
        await items.refresh()
        #expect(items[0]?.id == 0)
    }

    @Test("given refreshed items when subscript placeholder index then returns nil")
    func given_refreshedItems_when_subscriptPlaceholderIndex_then_returnsNil() async {
        let items = makeItems()
        await items.refresh()
        #expect(items[5] == nil)
    }

    @Test("given refreshed items when subscript read then anchorPosition is updated")
    func given_refreshedItems_when_subscriptRead_then_anchorPositionUpdated() async {
        let items = makeItems()
        await items.refresh()
        _ = items[7]
        #expect(items.anchorPosition == 7)
    }

    @Test("given refreshed items when peek called then anchorPosition is unchanged")
    func given_refreshedItems_when_peekCalled_then_anchorPositionUnchanged() async {
        let items = makeItems()
        await items.refresh()
        _ = items[3]
        _ = items.peek(at: 7)
        #expect(items.anchorPosition == 3)
    }

    @Test("given no placeholders reported when refreshed then itemsBefore and itemsAfter are zero")
    func given_noPlaceholdersReported_when_refreshed_then_itemsBeforeAndAfterAreZero() async {
        let items = makeItems(reportsPlaceholders: false)
        await items.refresh()
        #expect(items.itemsBefore == 0)
        #expect(items.itemsAfter == 0)
    }

    @Test("given negative index when subscript read then returns nil")
    func given_negativeIndex_when_subscriptRead_then_returnsNil() async {
        let items = makeItems()
        await items.refresh()
        #expect(items[-1] == nil)
    }
}
