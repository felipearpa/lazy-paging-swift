import Testing
@testable import LazyPaging

@Suite("Pager.stream")
struct PagerStreamTests {
    private func makePager() -> Pager<Int, TestItem> {
        Pager<Int, TestItem>(
            config: PagingConfig(pageSize: 2),
            pagingSourceFactory: { NumberPagingSource(totalPages: 3, pageSize: 2) },
            initialKey: 0
        )
    }

    @Test("given a pager when stream is subscribed then first PagingData is emitted")
    func given_pager_when_streamSubscribed_then_firstPagingDataEmitted() async {
        let pager = makePager()
        var iterator = pager.stream.makeAsyncIterator()
        let first = await iterator.next()
        #expect(first != nil)
    }

    @Test("given a subscribed stream when source invalidates then second PagingData is emitted")
    func given_subscribedStream_when_sourceInvalidates_then_secondPagingDataEmitted() async {
        let pager = makePager()
        var iterator = pager.stream.makeAsyncIterator()
        let first = await iterator.next()
        first?.source.invalidate()
        let second = await iterator.next()
        #expect(second != nil)
        #expect(first?.source !== second?.source)
    }
}
