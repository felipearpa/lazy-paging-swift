import Testing
@testable import LazyPaging

@Suite("PageFetcher")
struct PageFetcherTests {
    private func makePager(
        totalPages: Int = 5,
        pageSize: Int = 2,
        initialKey: Int = 0,
        maxSize: Int? = nil,
        prefetchDistance: Int? = nil
    ) -> Pager<Int, TestItem> {
        Pager<Int, TestItem>(
            config: PagingConfig(
                pageSize: pageSize,
                prefetchDistance: prefetchDistance,
                maxSize: maxSize
            ),
            pagingSourceFactory: { NumberPagingSource(totalPages: totalPages, pageSize: pageSize) },
            initialKey: initialKey
        )
    }

    @Test("given fresh fetcher when refresh called then first page is loaded")
    func given_freshFetcher_when_refresh_then_firstPageLoaded() async {
        let fetcher = PageFetcher(pager: makePager())
        let result = await fetcher.refresh(anchorPosition: nil, itemsBefore: 0)

        guard case .page(let items, _, let nextKey, _, _, _, _) = result else {
            Issue.record("expected .page"); return
        }
        #expect(items.map(\.id) == [0, 1])
        #expect(nextKey == 1)
    }

    @Test("given refreshed fetcher when append called then second page is loaded")
    func given_refreshedFetcher_when_append_then_secondPageLoaded() async {
        let fetcher = PageFetcher(pager: makePager())
        _ = await fetcher.refresh(anchorPosition: nil, itemsBefore: 0)
        let result = await fetcher.append()

        guard case .page(let items, _, _, _, _, _, _) = result else {
            Issue.record("expected .page"); return
        }
        #expect(items.map(\.id) == [2, 3])
    }

    @Test("given no previous key when prepend called then returns nil")
    func given_noPreviousKey_when_prepend_then_returnsNil() async {
        let fetcher = PageFetcher(pager: makePager(initialKey: 0))
        _ = await fetcher.refresh(anchorPosition: nil, itemsBefore: 0)
        let result = await fetcher.prepend()
        #expect(result == nil)
    }

    @Test("given next key when canAppend called then returns true")
    func given_nextKey_when_canAppend_then_returnsTrue() async {
        let fetcher = PageFetcher(pager: makePager())
        _ = await fetcher.refresh(anchorPosition: nil, itemsBefore: 0)
        let can = await fetcher.canAppend()
        #expect(can)
    }

    @Test("given no next key when canAppend called then returns false")
    func given_noNextKey_when_canAppend_then_returnsFalse() async {
        let fetcher = PageFetcher(pager: makePager(totalPages: 1))
        _ = await fetcher.refresh(anchorPosition: nil, itemsBefore: 0)
        let can = await fetcher.canAppend()
        #expect(!can)
    }

    @Test("given maxSize reached when append called then pages drop from head")
    func given_maxSizeReached_when_append_then_pagesDropFromHead() async {
        // pageSize 2, prefetch 0, maxSize 4 (>= 2*2 + 0). 3 pages → 6 items → drop 1 page.
        let fetcher = PageFetcher(pager: makePager(pageSize: 2, maxSize: 4, prefetchDistance: 0))
        _ = await fetcher.refresh(anchorPosition: nil, itemsBefore: 0)
        _ = await fetcher.append()
        let result = await fetcher.append()

        guard case .page(_, _, _, _, _, let droppedHead, _) = result else {
            Issue.record("expected .page"); return
        }
        #expect(droppedHead == 2)

        let pages = await fetcher.pages()
        #expect(pages.count == 2, "two pages remain after dropping one")
    }

    @Test("given failing source when refresh called then returns failure")
    func given_failingSource_when_refresh_then_returnsFailure() async {
        let pager = Pager<Int, TestItem>(
            config: PagingConfig(pageSize: 2),
            pagingSourceFactory: { FailingPagingSource(error: TestError(tag: "boom")) },
            initialKey: 0
        )
        let fetcher = PageFetcher(pager: pager)
        let result = await fetcher.refresh(anchorPosition: nil, itemsBefore: 0)

        guard case .failure = result else { Issue.record("expected .failure"); return }
    }
}
