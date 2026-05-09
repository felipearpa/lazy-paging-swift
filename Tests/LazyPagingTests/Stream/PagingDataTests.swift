import Testing
@testable import LazyPaging

@Suite("PagingData")
struct PagingDataTests {
    @Test("given a pager when pagingData is built then it wraps the pager's config and initial key")
    func given_pager_when_pagingDataBuilt_then_wrapsConfigAndInitialKey() {
        let pager = Pager<Int, TestItem>(
            config: PagingConfig(pageSize: 4),
            pagingSourceFactory: { NumberPagingSource(totalPages: 2, pageSize: 4) },
            initialKey: 0
        )
        let data = pager.pagingData()
        #expect(data.pager.config.pageSize == 4)
        #expect(data.pager.initialKey == 0)
    }
}
