import Testing
@testable import LazyPaging

@Suite("LoadStates")
struct LoadStatesTests {
    @Test("given idle when constructed then every axis is notLoading")
    func given_idle_when_constructed_then_everyAxisIsNotLoading() {
        let idle = LoadStates.idle
        #expect(idle.refresh.isNotLoading)
        #expect(idle.prepend.isNotLoading)
        #expect(idle.append.isNotLoading)
    }

    @Test("given idle when reading EOP flags then every axis is false")
    func given_idle_when_readingEOP_then_everyAxisIsFalse() {
        let idle = LoadStates.idle
        #expect(!idle.refresh.endOfPaginationReached)
        #expect(!idle.prepend.endOfPaginationReached)
        #expect(!idle.append.endOfPaginationReached)
    }
}

@Suite("CombinedLoadStates")
struct CombinedLoadStatesTests {
    @Test("given idle when constructed then source is idle and mediator is nil")
    func given_idle_when_constructed_then_sourceIsIdleAndMediatorIsNil() {
        let idle = CombinedLoadStates.idle
        #expect(idle.source == LoadStates.idle)
        #expect(idle.mediator == nil)
    }

    @Test("given failure and loading when combined then failure wins")
    func given_failureAndLoading_when_combined_then_failureWins() {
        let combined = CombinedLoadStates.combine(
            .failure(TestError(tag: "a")),
            .loading
        )
        #expect(combined.isFailure)
    }

    @Test("given loading and notLoading when combined then loading wins")
    func given_loadingAndNotLoading_when_combined_then_loadingWins() {
        let combined = CombinedLoadStates.combine(
            .loading,
            .notLoading(endOfPaginationReached: false)
        )
        #expect(combined.isLoading)
    }

    @Test("given two notLoading when combined then returns left-hand state")
    func given_twoNotLoading_when_combined_then_returnsLeft() {
        let left = LoadState.notLoading(endOfPaginationReached: true)
        let right = LoadState.notLoading(endOfPaginationReached: false)
        let combined = CombinedLoadStates.combine(left, right)
        #expect(combined == left)
    }

    @Test("given notLoading on left and failure on right when combined then failure wins")
    func given_notLoadingLeftFailureRight_when_combined_then_failureWins() {
        let combined = CombinedLoadStates.combine(
            .notLoading(endOfPaginationReached: false),
            .failure(TestError(tag: "b"))
        )
        #expect(combined.isFailure)
    }
}
