import Testing
@testable import LazyPaging

@Suite("PagingConfig")
struct PagingConfigTests {
    @Test("given only pageSize when initialised then initialLoadSize defaults to pageSize")
    func given_onlyPageSize_when_initialised_then_initialLoadSizeDefaultsToPageSize() {
        let config = PagingConfig(pageSize: 20)
        #expect(config.initialLoadSize == 20)
    }

    @Test("given only pageSize when initialised then prefetchDistance defaults to pageSize")
    func given_onlyPageSize_when_initialised_then_prefetchDistanceDefaultsToPageSize() {
        let config = PagingConfig(pageSize: 20)
        #expect(config.prefetchDistance == 20)
    }

    @Test("given only pageSize when initialised then maxSize is nil")
    func given_onlyPageSize_when_initialised_then_maxSizeIsNil() {
        let config = PagingConfig(pageSize: 20)
        #expect(config.maxSize == nil)
    }

    @Test("given explicit initialLoadSize when initialised then it overrides the default")
    func given_explicitInitialLoadSize_when_initialised_then_overridesDefault() {
        let config = PagingConfig(pageSize: 20, initialLoadSize: 60)
        #expect(config.initialLoadSize == 60)
    }

    @Test("given explicit prefetchDistance when initialised then it overrides the default")
    func given_explicitPrefetchDistance_when_initialised_then_overridesDefault() {
        let config = PagingConfig(pageSize: 20, prefetchDistance: 5)
        #expect(config.prefetchDistance == 5)
    }

    @Test("given valid maxSize when initialised then it is stored")
    func given_validMaxSize_when_initialised_then_isStored() {
        // maxSize must be >= pageSize*2 + prefetchDistance → 20*2 + 5 = 45.
        let config = PagingConfig(pageSize: 20, prefetchDistance: 5, maxSize: 50)
        #expect(config.maxSize == 50)
    }

    @Test("given two equal configs when compared then they are equal")
    func given_twoEqualConfigs_when_compared_then_equal() {
        let a = PagingConfig(pageSize: 20)
        let b = PagingConfig(pageSize: 20)
        #expect(a == b)
    }
}
