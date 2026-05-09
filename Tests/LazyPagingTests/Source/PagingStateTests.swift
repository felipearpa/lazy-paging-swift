import Testing
@testable import LazyPaging

@Suite("PagingState")
struct PagingStateTests {
    private let config = PagingConfig(pageSize: 3)

    private func makeState(
        pages: [LoadedPage<Int, TestItem>],
        anchor: Int? = nil,
        leadingPlaceholderCount: Int = 0
    ) -> PagingState<Int, TestItem> {
        PagingState(
            pages: pages,
            anchorPosition: anchor,
            config: config,
            leadingPlaceholderCount: leadingPlaceholderCount
        )
    }

    @Test("given empty pages when isEmpty then returns true")
    func given_emptyPages_when_isEmpty_then_returnsTrue() {
        let state = makeState(pages: [])
        #expect(state.isEmpty)
    }

    @Test("given empty pages when closestPageToPosition then returns nil")
    func given_emptyPages_when_closestPageToPosition_then_returnsNil() {
        let state = makeState(pages: [])
        #expect(state.closestPageToPosition(0) == nil)
    }

    @Test("given anchor inside first page when closestPageToPosition then returns first page")
    func given_anchorInsideFirstPage_when_closestPageToPosition_then_returnsFirstPage() {
        let page0 = LoadedPage<Int, TestItem>(items: [TestItem(id: 0), TestItem(id: 1), TestItem(id: 2)], previousKey: nil, nextKey: 1)
        let page1 = LoadedPage<Int, TestItem>(items: [TestItem(id: 3), TestItem(id: 4), TestItem(id: 5)], previousKey: 0, nextKey: 2)
        let state = makeState(pages: [page0, page1])
        #expect(state.closestPageToPosition(1)?.items == page0.items)
    }

    @Test("given anchor inside second page when closestPageToPosition then returns second page")
    func given_anchorInsideSecondPage_when_closestPageToPosition_then_returnsSecondPage() {
        let page0 = LoadedPage<Int, TestItem>(items: [TestItem(id: 0), TestItem(id: 1), TestItem(id: 2)], previousKey: nil, nextKey: 1)
        let page1 = LoadedPage<Int, TestItem>(items: [TestItem(id: 3), TestItem(id: 4), TestItem(id: 5)], previousKey: 0, nextKey: 2)
        let state = makeState(pages: [page0, page1])
        #expect(state.closestPageToPosition(4)?.items == page1.items)
    }

    @Test("given leading placeholders when closestPageToPosition then absolute index maps correctly")
    func given_leadingPlaceholders_when_closestPageToPosition_then_absoluteIndexMapsCorrectly() {
        let page0 = LoadedPage<Int, TestItem>(items: [TestItem(id: 10), TestItem(id: 11), TestItem(id: 12)], previousKey: 9, nextKey: 11)
        let page1 = LoadedPage<Int, TestItem>(items: [TestItem(id: 13), TestItem(id: 14), TestItem(id: 15)], previousKey: 10, nextKey: 12)
        let state = makeState(pages: [page0, page1], leadingPlaceholderCount: 10)
        #expect(state.closestPageToPosition(14)?.items == page1.items)
    }

    @Test("given loaded items when closestItemToPosition then returns item at index")
    func given_loadedItems_when_closestItemToPosition_then_returnsItemAtIndex() {
        let page0 = LoadedPage<Int, TestItem>(items: [TestItem(id: 0), TestItem(id: 1), TestItem(id: 2)], previousKey: nil, nextKey: 1)
        let state = makeState(pages: [page0])
        #expect(state.closestItemToPosition(2)?.id == 2)
    }

    @Test("given pages when items is read then returns flattened list")
    func given_pages_when_itemsIsRead_then_returnsFlattenedList() {
        let page0 = LoadedPage<Int, TestItem>(items: [TestItem(id: 0)], previousKey: nil, nextKey: 1)
        let page1 = LoadedPage<Int, TestItem>(items: [TestItem(id: 1), TestItem(id: 2)], previousKey: 0, nextKey: nil)
        let state = makeState(pages: [page0, page1])
        #expect(state.items.map(\.id) == [0, 1, 2])
    }
}
