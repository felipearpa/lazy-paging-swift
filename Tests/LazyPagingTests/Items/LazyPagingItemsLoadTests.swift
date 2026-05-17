import Testing
@testable import LazyPaging

@Suite("LazyPagingItems / refresh, append, prepend, retry")
@MainActor
struct LazyPagingItemsLoadTests {
    private func makeItems(
        totalPages: Int = 5,
        pageSize: Int = 2,
        initialKey: Int = 0,
        prefetchDistance: Int? = nil
    ) -> LazyPagingItems<Int, TestItem> {
        let pager = Pager<Int, TestItem>(
            config: PagingConfig(pageSize: pageSize, prefetchDistance: prefetchDistance),
            pagingSourceFactory: { NumberPagingSource(totalPages: totalPages, pageSize: pageSize) },
            initialKey: initialKey
        )
        return LazyPagingItems(pager: pager)
    }

    @Test("given fresh items when refresh called then loadedItems contains first page")
    func given_freshItems_when_refresh_then_loadedItemsContainsFirstPage() async {
        let items = makeItems()
        await items.refresh()
        #expect(items.loadedItems.map(\.id) == [0, 1])
    }

    @Test("given refreshed items when appendIfNeeded within prefetch then next page loads")
    func given_refreshedItems_when_appendIfNeededWithinPrefetch_then_nextPageLoads() async {
        let items = makeItems(prefetchDistance: 0)
        await items.refresh()
        await items.appendIfNeeded(currentIndex: 1) // lastLoadedIndex = 1 → exactly at edge
        #expect(items.loadedItems.contains(where: { $0.id == 2 }))
    }

    @Test("given refreshed items when appendIfNeeded far from end then no load happens")
    func given_refreshedItems_when_appendIfNeededFarFromEnd_then_noLoad() async {
        let items = makeItems(totalPages: 10, pageSize: 2, prefetchDistance: 0)
        await items.refresh()
        await items.appendIfNeeded(currentIndex: 0) // head of list, no fetch
        #expect(items.loadedItems.count == 2, "only the refreshed page should be loaded")
    }

    @Test("given bidirectional items when prependIfNeeded within prefetch then previous page loads")
    func given_bidirectionalItems_when_prependIfNeededWithinPrefetch_then_previousPageLoads() async {
        let items = makeItems(totalPages: 5, pageSize: 2, initialKey: 2, prefetchDistance: 0)
        await items.refresh()
        await items.prependIfNeeded(currentIndex: 4) // itemsBefore = 4 → prepend needed
        #expect(items.loadedItems.contains(where: { $0.id == 2 }))
    }

    @Test("given loaded items when onRowAccess called then anchor updates and prefetch can run")
    func given_loadedItems_when_onRowAccess_then_anchorUpdates() async {
        let items = makeItems()
        await items.refresh()
        await items.onRowAccess(index: 1)
        #expect(items.anchorPosition == 1)
    }

    @Test("given failing source when refresh called then loadState.refresh is failure")
    func given_failingSource_when_refresh_then_loadStateRefreshIsFailure() async {
        let pager = Pager<Int, TestItem>(
            config: PagingConfig(pageSize: 2),
            pagingSourceFactory: { FailingPagingSource(error: TestError(tag: "x")) },
            initialKey: 0
        )
        let items = LazyPagingItems(pager: pager)
        await items.refresh()
        #expect(items.loadState.refresh.isFailure)
    }

    @Test("given failing refresh when retry called then refresh is replayed")
    func given_failingRefresh_when_retry_then_refreshReplayed() async {
        let pager = Pager<Int, TestItem>(
            config: PagingConfig(pageSize: 2),
            pagingSourceFactory: { FailingPagingSource(error: TestError(tag: "x")) },
            initialKey: 0
        )
        let items = LazyPagingItems(pager: pager)
        await items.refresh()

        // Retrying again just replays the failing refresh — state stays failure.
        await items.retry()
        #expect(items.loadState.refresh.isFailure)
    }

    @Test("given append failure when subsequent appendIfNeeded fires then no auto-retry")
    func given_appendFailure_when_appendIfNeededFires_then_noAutoRetry() async {
        let error = TestError(tag: "append-fail")
        let source = FailingOnPagePagingSource(
            totalPages: 5, pageSize: 2, failingPage: 1, error: error
        )
        let pager = Pager<Int, TestItem>(
            config: PagingConfig(pageSize: 2, prefetchDistance: 0),
            pagingSourceFactory: { source },
            initialKey: 0
        )
        let items = LazyPagingItems(pager: pager)
        await items.refresh()

        // First trigger: page 1 attempted, fails, state becomes .failure.
        await items.appendIfNeeded(currentIndex: 1)
        #expect(items.loadState.append.isFailure)
        #expect(source.loadCount(forPage: 1) == 1)

        // Second + third triggers from row tasks must be short-circuited by
        // the .failure guard — load() should NOT be called again.
        await items.appendIfNeeded(currentIndex: 1)
        await items.appendIfNeeded(currentIndex: 1)
        #expect(source.loadCount(forPage: 1) == 1, "row-driven appendIfNeeded must not auto-retry after failure")
        #expect(items.loadState.append.isFailure, "state must remain .failure")

        // Explicit retry() must still re-attempt the load.
        await items.retry()
        #expect(source.loadCount(forPage: 1) == 2, "retry() must re-attempt the failed load")
    }

    @Test("given prepend failure when subsequent prependIfNeeded fires then no auto-retry")
    func given_prependFailure_when_prependIfNeededFires_then_noAutoRetry() async {
        let error = TestError(tag: "prepend-fail")
        let source = FailingOnPagePagingSource(
            totalPages: 5, pageSize: 2, failingPage: 1, error: error
        )
        let pager = Pager<Int, TestItem>(
            config: PagingConfig(pageSize: 2, prefetchDistance: 0),
            pagingSourceFactory: { source },
            initialKey: 2
        )
        let items = LazyPagingItems(pager: pager)
        await items.refresh()

        // currentIndex 4 == itemsBefore, so isPrependNeeded fires.
        await items.prependIfNeeded(currentIndex: 4)
        #expect(items.loadState.prepend.isFailure)
        #expect(source.loadCount(forPage: 1) == 1)

        await items.prependIfNeeded(currentIndex: 4)
        await items.prependIfNeeded(currentIndex: 4)
        #expect(source.loadCount(forPage: 1) == 1, "row-driven prependIfNeeded must not auto-retry after failure")
        #expect(items.loadState.prepend.isFailure)

        await items.retry()
        #expect(source.loadCount(forPage: 1) == 2, "retry() must re-attempt the failed prepend")
    }

    @Test("given enablePlaceholders false when refresh then placeholder counts are zeroed")
    func given_enablePlaceholdersFalse_when_refresh_then_placeholderCountsAreZeroed() async {
        // Source reports real itemsBefore/itemsAfter, but config switches them off.
        let pager = Pager<Int, TestItem>(
            config: PagingConfig(pageSize: 2, enablePlaceholders: false),
            pagingSourceFactory: { NumberPagingSource(totalPages: 5, pageSize: 2) },
            initialKey: 2
        )
        let items = LazyPagingItems(pager: pager)
        await items.refresh()
        #expect(items.itemsBefore == 0)
        #expect(items.itemsAfter == 0)
        #expect(items.itemCount == items.loadedItems.count)
    }

    @Test("given enablePlaceholders true when refresh then source placeholder counts surface")
    func given_enablePlaceholdersTrue_when_refresh_then_sourcePlaceholderCountsSurface() async {
        // Sanity-check baseline: the same source with placeholders enabled
        // still reports nonzero itemsBefore/itemsAfter.
        let pager = Pager<Int, TestItem>(
            config: PagingConfig(pageSize: 2),
            pagingSourceFactory: { NumberPagingSource(totalPages: 5, pageSize: 2) },
            initialKey: 2
        )
        let items = LazyPagingItems(pager: pager)
        await items.refresh()
        #expect(items.itemsBefore == 4)
        #expect(items.itemsAfter == 4)
    }

    @Test("given enablePlaceholders false with maxSize drop then dropped pages do not bump placeholders")
    func given_enablePlaceholdersFalse_with_maxSizeDrop_then_droppedPagesDoNotBumpPlaceholders() async {
        // pageSize 2, prefetchDistance 0, maxSize 4 → pageSize*2 + prefetch = 4
        // → after one append, the head page must drop.
        let pager = Pager<Int, TestItem>(
            config: PagingConfig(
                pageSize: 2,
                prefetchDistance: 0,
                maxSize: 4,
                enablePlaceholders: false
            ),
            pagingSourceFactory: { NumberPagingSource(totalPages: 5, pageSize: 2) },
            initialKey: 0
        )
        let items = LazyPagingItems(pager: pager)
        await items.refresh()
        await items.appendIfNeeded(currentIndex: 1) // triggers append, head drops
        await items.appendIfNeeded(currentIndex: 3) // triggers another append, head drops again
        #expect(items.itemsBefore == 0, "dropped head pages must not synthesize placeholders")
        #expect(items.itemsAfter == 0)
    }

    @Test("given source returning invalid then items stay empty after recovery refresh")
    func given_sourceReturningInvalid_when_refresh_then_refreshIsRetried() async {
        let pager = Pager<Int, TestItem>(
            config: PagingConfig(pageSize: 2),
            pagingSourceFactory: { FlakyInvalidatingSource() },
            initialKey: 0
        )
        let items = LazyPagingItems(pager: pager)
        await items.refresh()

        // The second refresh (triggered by .invalid) is launched on a detached
        // Task. Give it a tick to complete.
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(items.loadedItems.count == 2)
    }
}
