import Foundation
import Testing
@testable import LazyPaging

@Suite("RemoteMediator coordination")
@MainActor
struct RemoteMediatorTests {
    // MARK: - Shared store used by mediator + source

    private final class Store: @unchecked Sendable {
        private let lock = NSLock()
        private var pages: [[TestItem]] = []

        func append(_ page: [TestItem]) {
            lock.lock(); defer { lock.unlock() }
            pages.append(page)
        }

        func reset(_ initial: [[TestItem]]) {
            lock.lock(); defer { lock.unlock() }
            pages = initial
        }

        func page(at index: Int) -> [TestItem]? {
            lock.lock(); defer { lock.unlock() }
            return (0..<pages.count).contains(index) ? pages[index] : nil
        }

        var pageCount: Int {
            lock.lock(); defer { lock.unlock() }
            return pages.count
        }
    }

    private final class StoreSource: PagingSource<Int, TestItem>, @unchecked Sendable {
        let store: Store
        init(store: Store) { self.store = store; super.init() }

        override func load(loadConfig: LoadConfig<Int>) async -> LoadResult<Int, TestItem> {
            let page = loadConfig.key ?? 0
            guard let items = store.page(at: page) else {
                return .page(items: [], previousKey: nil, nextKey: nil)
            }
            return .page(
                items: items,
                previousKey: page > 0 ? page - 1 : nil,
                nextKey: page + 1 < store.pageCount ? page + 1 : nil
            )
        }
    }

    private final class RecordingMediator: RemoteMediator, @unchecked Sendable {
        typealias Key = Int
        typealias Item = TestItem

        let store: Store
        let initializeResult: InitializeAction
        let refreshError: TestError?

        private let lock = NSLock()
        private(set) var refreshCalls = 0

        init(store: Store, initializeResult: InitializeAction = .launchInitialRefresh, refreshError: TestError? = nil) {
            self.store = store
            self.initializeResult = initializeResult
            self.refreshError = refreshError
        }

        func initialize() async -> InitializeAction { initializeResult }

        func load(loadType: LoadType, state: PagingState<Int, TestItem>) async -> MediatorResult {
            if loadType == .refresh {
                lock.lock(); refreshCalls += 1; lock.unlock()
                if let refreshError { return .failure(refreshError) }
                store.reset([(0..<3).map { TestItem(id: $0) }])
                return .success(endOfPaginationReached: false)
            }
            return .success(endOfPaginationReached: true)
        }
    }

    // MARK: - Tests

    @Test("given a mediator when refresh is called then mediator runs before source")
    func given_mediator_when_refresh_then_mediatorRunsBeforeSource() async {
        let store = Store()
        let mediator = RecordingMediator(store: store)
        let pager = Pager<Int, TestItem>(
            config: PagingConfig(pageSize: 3),
            remoteMediator: mediator,
            pagingSourceFactory: { [store] in StoreSource(store: store) },
            initialKey: 0
        )
        let items = LazyPagingItems(pager: pager)
        await items.refresh()

        #expect(mediator.refreshCalls == 1)
        #expect(items.loadedItems.map(\.id) == [0, 1, 2])
    }

    @Test("given mediator that skips initialRefresh when refresh is called then mediator does not run")
    func given_mediatorThatSkipsInitialRefresh_when_refresh_then_mediatorDoesNotRun() async {
        let store = Store()
        store.reset([(0..<3).map { TestItem(id: $0) }])
        let mediator = RecordingMediator(store: store, initializeResult: .skipInitialRefresh)

        let pager = Pager<Int, TestItem>(
            config: PagingConfig(pageSize: 3),
            remoteMediator: mediator,
            pagingSourceFactory: { [store] in StoreSource(store: store) },
            initialKey: 0
        )
        let items = LazyPagingItems(pager: pager)
        await items.refresh()

        #expect(mediator.refreshCalls == 0)
        #expect(items.loadedItems.map(\.id) == [0, 1, 2])
    }

    @Test("given mediator that fails on refresh when refresh is called then mediator loadState is failure")
    func given_mediatorThatFailsOnRefresh_when_refresh_then_mediatorLoadStateIsFailure() async {
        let store = Store()
        store.reset([(0..<3).map { TestItem(id: $0) }])
        let mediator = RecordingMediator(store: store, refreshError: TestError(tag: "boom"))

        let pager = Pager<Int, TestItem>(
            config: PagingConfig(pageSize: 3),
            remoteMediator: mediator,
            pagingSourceFactory: { [store] in StoreSource(store: store) },
            initialKey: 0
        )
        let items = LazyPagingItems(pager: pager)
        await items.refresh()

        #expect(items.loadState.mediator?.refresh.isFailure == true)
        #expect(items.loadState.refresh.isFailure)
        #expect(items.loadedItems.isEmpty, "source never ran because mediator failed")
    }

    @Test("given a pager without a mediator when items are built then mediator loadState is nil")
    func given_pagerWithoutMediator_when_itemsBuilt_then_mediatorLoadStateIsNil() async {
        let pager = Pager<Int, TestItem>(
            config: PagingConfig(pageSize: 2),
            pagingSourceFactory: { NumberPagingSource(totalPages: 1, pageSize: 2) },
            initialKey: 0
        )
        let items = LazyPagingItems(pager: pager)
        #expect(items.loadState.mediator == nil)
    }
}

// MARK: - default initialize()

@Suite("RemoteMediator default initialize")
struct RemoteMediatorDefaultInitializeTests {
    private struct Stub: RemoteMediator {
        typealias Key = Int
        typealias Item = TestItem
        func load(loadType: LoadType, state: PagingState<Int, TestItem>) async -> MediatorResult {
            .success(endOfPaginationReached: true)
        }
    }

    @Test("given a mediator without a custom initialize when initialize called then returns launchInitialRefresh")
    func given_mediatorWithoutCustomInitialize_when_initializeCalled_then_returnsLaunchInitialRefresh() async {
        let action = await Stub().initialize()
        #expect(action == .launchInitialRefresh)
    }
}
