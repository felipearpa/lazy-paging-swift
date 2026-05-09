import Testing
@testable import LazyPaging

@Suite("PagingSource")
struct PagingSourceTests {
    @Test("given default source when getRefreshKey is called then returns nil")
    func given_defaultSource_when_getRefreshKeyCalled_then_returnsNil() {
        let source = NumberPagingSource(totalPages: 1, pageSize: 10)
        let state = PagingState<Int, TestItem>(
            pages: [],
            anchorPosition: nil,
            config: PagingConfig(pageSize: 10),
            leadingPlaceholderCount: 0
        )
        #expect(source.getRefreshKey(state: state) == nil)
    }

    @Test("given registered action when invalidate called then action fires")
    func given_registeredAction_when_invalidateCalled_then_actionFires() async throws {
        let source = NumberPagingSource(totalPages: 1, pageSize: 10)
        let (signal, continuation) = AsyncStream<Void>.makeStream()

        _ = await source.registerInvalidateAction {
            continuation.yield()
        }
        source.invalidate()

        var iterator = signal.makeAsyncIterator()
        let fired = await iterator.next()
        #expect(fired != nil)
        continuation.finish()
    }

    @Test("given unregistered action when invalidate called then action does not fire")
    func given_unregisteredAction_when_invalidateCalled_then_actionDoesNotFire() async throws {
        let source = NumberPagingSource(totalPages: 1, pageSize: 10)
        let counter = AtomicCounter()

        let id = await source.registerInvalidateAction {
            await counter.increment()
        }
        await source.unregisterInvalidateAction(id: id)
        source.invalidate()

        // Give the async task time to fire (if it were going to).
        try await Task.sleep(nanoseconds: 50_000_000)
        let count = await counter.value
        #expect(count == 0)
    }
}

actor AtomicCounter {
    private(set) var value: Int = 0
    func increment() { value += 1 }
}
