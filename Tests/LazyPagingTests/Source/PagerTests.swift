import Testing
@testable import LazyPaging

@Suite("Pager")
struct PagerTests {
    @Test("given a factory when pagingData called twice then distinct sources are returned")
    func given_factory_when_pagingDataCalledTwice_then_distinctSourcesAreReturned() {
        let pager = Pager<Int, TestItem>(
            config: PagingConfig(pageSize: 10),
            pagingSourceFactory: { NumberPagingSource(totalPages: 3, pageSize: 10) },
            initialKey: 0
        )
        let a = pager.pagingData()
        let b = pager.pagingData()
        #expect(a.source !== b.source)
    }

    @Test("given no mediator when constructed then remoteMediator is nil")
    func given_noMediator_when_constructed_then_remoteMediatorIsNil() {
        let pager = Pager<Int, TestItem>(
            config: PagingConfig(pageSize: 10),
            pagingSourceFactory: { NumberPagingSource(totalPages: 1, pageSize: 10) }
        )
        #expect(pager.remoteMediator == nil)
    }

    @Test("given initialKey when constructed then field is stored")
    func given_initialKey_when_constructed_then_fieldIsStored() {
        let pager = Pager<Int, TestItem>(
            config: PagingConfig(pageSize: 10),
            pagingSourceFactory: { NumberPagingSource(totalPages: 1, pageSize: 10) },
            initialKey: 7
        )
        #expect(pager.initialKey == 7)
    }
}
