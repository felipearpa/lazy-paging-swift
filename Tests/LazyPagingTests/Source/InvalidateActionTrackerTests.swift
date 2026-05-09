import Testing
@testable import LazyPaging

@Suite("InvalidateActionTracker")
struct InvalidateActionTrackerTests {
    @Test("given a registered action when invalidate called then the action runs")
    func given_registeredAction_when_invalidate_then_runs() async {
        let tracker = InvalidateActionTracker()
        let counter = AtomicCounter()
        _ = await tracker.register { await counter.increment() }

        await tracker.invalidate()

        let count = await counter.value
        #expect(count == 1)
    }

    @Test("given two registered actions when invalidate called then both run")
    func given_twoRegisteredActions_when_invalidate_then_bothRun() async {
        let tracker = InvalidateActionTracker()
        let counter = AtomicCounter()
        _ = await tracker.register { await counter.increment() }
        _ = await tracker.register { await counter.increment() }

        await tracker.invalidate()

        let count = await counter.value
        #expect(count == 2)
    }

    @Test("given an action that is unregistered when invalidate called then the action does not run")
    func given_unregisteredAction_when_invalidate_then_doesNotRun() async {
        let tracker = InvalidateActionTracker()
        let counter = AtomicCounter()
        let id = await tracker.register { await counter.increment() }

        await tracker.unregister(id: id)
        await tracker.invalidate()

        let count = await counter.value
        #expect(count == 0)
    }

    @Test("given register called twice when ids are compared then they differ")
    func given_registerCalledTwice_when_idsCompared_then_differ() async {
        let tracker = InvalidateActionTracker()
        let idA = await tracker.register {}
        let idB = await tracker.register {}
        #expect(idA != idB)
    }
}
