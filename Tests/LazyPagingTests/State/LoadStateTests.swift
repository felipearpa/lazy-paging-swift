import Testing
@testable import LazyPaging

@Suite("LoadState")
struct LoadStateTests {
    @Test("given notLoading when isNotLoading then returns true")
    func given_notLoading_when_isNotLoading_then_returnsTrue() {
        #expect(LoadState.notLoading(endOfPaginationReached: false).isNotLoading)
    }

    @Test("given loading when isLoading then returns true")
    func given_loading_when_isLoading_then_returnsTrue() {
        #expect(LoadState.loading.isLoading)
    }

    @Test("given failure when isFailure then returns true")
    func given_failure_when_isFailure_then_returnsTrue() {
        #expect(LoadState.failure(TestError(tag: "x")).isFailure)
    }

    @Test("given notLoading when isLoading then returns false")
    func given_notLoading_when_isLoading_then_returnsFalse() {
        #expect(!LoadState.notLoading(endOfPaginationReached: false).isLoading)
    }

    @Test("given notLoading with EOP when endOfPaginationReached then returns true")
    func given_notLoadingEOP_when_endOfPaginationReached_then_returnsTrue() {
        #expect(LoadState.notLoading(endOfPaginationReached: true).endOfPaginationReached)
    }

    @Test("given loading when endOfPaginationReached then returns false")
    func given_loading_when_endOfPaginationReached_then_returnsFalse() {
        #expect(!LoadState.loading.endOfPaginationReached)
    }

    @Test("given failure when endOfPaginationReached then returns false")
    func given_failure_when_endOfPaginationReached_then_returnsFalse() {
        #expect(!LoadState.failure(TestError(tag: "x")).endOfPaginationReached)
    }

    @Test("given failure when reading error then returns stored error")
    func given_failure_when_readingError_then_returnsStoredError() {
        let error = TestError(tag: "boom")
        let read = LoadState.failure(error).error as? TestError
        #expect(read == error)
    }

    @Test("given notLoading when reading error then returns nil")
    func given_notLoading_when_readingError_then_returnsNil() {
        #expect(LoadState.notLoading(endOfPaginationReached: false).error == nil)
    }

    @Test("given identical notLoading states when compared then they are equal")
    func given_identicalNotLoading_when_compared_then_equal() {
        #expect(LoadState.notLoading(endOfPaginationReached: true)
                == LoadState.notLoading(endOfPaginationReached: true))
    }

    @Test("given notLoading states with different EOP when compared then they differ")
    func given_differentNotLoadingEOP_when_compared_then_notEqual() {
        #expect(LoadState.notLoading(endOfPaginationReached: true)
                != LoadState.notLoading(endOfPaginationReached: false))
    }

    @Test("given two loading states when compared then they are equal")
    func given_twoLoading_when_compared_then_equal() {
        #expect(LoadState.loading == LoadState.loading)
    }

    @Test("given failure states with same error type when compared then they are equal")
    func given_failuresSameType_when_compared_then_equal() {
        #expect(LoadState.failure(TestError(tag: "a"))
                == LoadState.failure(TestError(tag: "b")))
    }

    @Test("given loading vs notLoading when compared then they differ")
    func given_loadingVsNotLoading_when_compared_then_notEqual() {
        #expect(LoadState.loading != .notLoading(endOfPaginationReached: false))
    }
}
