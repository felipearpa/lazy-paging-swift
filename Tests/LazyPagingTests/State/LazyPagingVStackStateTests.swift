import Testing
@testable import LazyPaging

@Suite("LazyPagingVStackState")
struct LazyPagingVStackStateTests {
    @Test("given loading when isLoading then returns true")
    func given_loading_when_isLoading_then_returnsTrue() {
        #expect(LazyPagingVStackState.loading.isLoading)
    }

    @Test("given empty when isEmpty then returns true")
    func given_empty_when_isEmpty_then_returnsTrue() {
        #expect(LazyPagingVStackState.empty.isEmpty)
    }

    @Test("given error when isError then returns true")
    func given_error_when_isError_then_returnsTrue() {
        #expect(LazyPagingVStackState.error(TestError(tag: "x")).isError)
    }

    @Test("given content when isContent then returns true")
    func given_content_when_isContent_then_returnsTrue() {
        #expect(LazyPagingVStackState.content.isContent)
    }

    @Test("given content when isLoading then returns false")
    func given_content_when_isLoading_then_returnsFalse() {
        #expect(!LazyPagingVStackState.content.isLoading)
    }

    @Test("given error when reading error then returns stored error")
    func given_error_when_readingError_then_returnsStoredError() {
        let error = TestError(tag: "nope")
        let read = LazyPagingVStackState.error(error).error as? TestError
        #expect(read == error)
    }

    @Test("given loading when reading error then returns nil")
    func given_loading_when_readingError_then_returnsNil() {
        #expect(LazyPagingVStackState.loading.error == nil)
    }
}
