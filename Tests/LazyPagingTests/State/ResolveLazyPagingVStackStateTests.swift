import Testing
@testable import LazyPaging

@Suite("resolveLazyPagingVStackState")
struct ResolveLazyPagingVStackStateTests {
    @Test("given refresh failure when resolved then returns error")
    func given_refreshFailure_when_resolved_then_returnsError() {
        let state = resolveLazyPagingVStackState(
            refresh: .failure(TestError(tag: "boom")),
            prepend: .notLoading(endOfPaginationReached: false),
            append: .notLoading(endOfPaginationReached: false),
            itemCount: 0,
            current: .content
        )
        #expect(state.isError)
    }

    @Test("given no items and both ends reached when refresh is notLoading then returns empty")
    func given_noItemsAndBothEndsReached_when_refreshNotLoading_then_returnsEmpty() {
        let state = resolveLazyPagingVStackState(
            refresh: .notLoading(endOfPaginationReached: true),
            prepend: .notLoading(endOfPaginationReached: true),
            append: .notLoading(endOfPaginationReached: true),
            itemCount: 0,
            current: .loading
        )
        #expect(state.isEmpty)
    }

    @Test("given items present when refresh is notLoading then returns content")
    func given_itemsPresent_when_refreshNotLoading_then_returnsContent() {
        let state = resolveLazyPagingVStackState(
            refresh: .notLoading(endOfPaginationReached: false),
            prepend: .notLoading(endOfPaginationReached: false),
            append: .notLoading(endOfPaginationReached: false),
            itemCount: 5,
            current: .loading
        )
        #expect(state.isContent)
    }

    @Test("given no items and prepend still paging when refresh is notLoading then returns loading")
    func given_noItemsAndPrependStillPaging_when_refreshNotLoading_then_returnsLoading() {
        let state = resolveLazyPagingVStackState(
            refresh: .notLoading(endOfPaginationReached: false),
            prepend: .notLoading(endOfPaginationReached: false),
            append: .notLoading(endOfPaginationReached: true),
            itemCount: 0,
            current: .loading
        )
        #expect(state.isLoading)
    }

    @Test("given no items and append still paging when refresh is notLoading then returns loading")
    func given_noItemsAndAppendStillPaging_when_refreshNotLoading_then_returnsLoading() {
        let state = resolveLazyPagingVStackState(
            refresh: .notLoading(endOfPaginationReached: false),
            prepend: .notLoading(endOfPaginationReached: true),
            append: .notLoading(endOfPaginationReached: false),
            itemCount: 0,
            current: .loading
        )
        #expect(state.isLoading)
    }

    @Test("given current content when refresh is loading then preserves content")
    func given_currentContent_when_refreshLoading_then_preservesContent() {
        let state = resolveLazyPagingVStackState(
            refresh: .loading,
            prepend: .notLoading(endOfPaginationReached: false),
            append: .notLoading(endOfPaginationReached: false),
            itemCount: 10,
            current: .content
        )
        #expect(state.isContent)
    }

    @Test("given current empty when refresh is loading then preserves empty")
    func given_currentEmpty_when_refreshLoading_then_preservesEmpty() {
        let state = resolveLazyPagingVStackState(
            refresh: .loading,
            prepend: .notLoading(endOfPaginationReached: true),
            append: .notLoading(endOfPaginationReached: true),
            itemCount: 0,
            current: .empty
        )
        #expect(state.isEmpty)
    }

    @Test("given current error when refresh is loading then preserves error")
    func given_currentError_when_refreshLoading_then_preservesError() {
        let state = resolveLazyPagingVStackState(
            refresh: .loading,
            prepend: .notLoading(endOfPaginationReached: false),
            append: .notLoading(endOfPaginationReached: false),
            itemCount: 0,
            current: .error(TestError(tag: "previous"))
        )
        #expect(state.isError)
    }

    @Test("given current loading when refresh is loading then stays loading")
    func given_currentLoading_when_refreshLoading_then_staysLoading() {
        let state = resolveLazyPagingVStackState(
            refresh: .loading,
            prepend: .notLoading(endOfPaginationReached: false),
            append: .notLoading(endOfPaginationReached: false),
            itemCount: 0,
            current: .loading
        )
        #expect(state.isLoading)
    }
}
