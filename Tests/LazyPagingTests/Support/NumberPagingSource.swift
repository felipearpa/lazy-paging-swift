import Foundation
@testable import LazyPaging

/// Deterministic paging source used by fetcher / items / stream suites.
/// Pages are numbered 0..<totalPages, pageSize items each, item ids running
/// 0, 1, 2, …
final class NumberPagingSource: PagingSource<Int, TestItem>, @unchecked Sendable {
    let totalPages: Int
    let pageSize: Int
    let reportsPlaceholders: Bool

    init(totalPages: Int, pageSize: Int, reportsPlaceholders: Bool = true) {
        self.totalPages = totalPages
        self.pageSize = pageSize
        self.reportsPlaceholders = reportsPlaceholders
        super.init()
    }

    override func load(loadConfig: LoadConfig<Int>) async -> LoadResult<Int, TestItem> {
        let page = loadConfig.key ?? 0
        guard (0..<totalPages).contains(page) else {
            return .page(items: [], previousKey: nil, nextKey: nil)
        }
        let start = page * pageSize
        let items = (0..<pageSize).map { TestItem(id: start + $0) }
        return .page(
            items: items,
            previousKey: page > 0 ? page - 1 : nil,
            nextKey: page + 1 < totalPages ? page + 1 : nil,
            itemsBefore: reportsPlaceholders ? start : 0,
            itemsAfter: reportsPlaceholders ? (totalPages - page - 1) * pageSize : 0
        )
    }
}

/// Source that fails every load with the given error.
final class FailingPagingSource: PagingSource<Int, TestItem>, @unchecked Sendable {
    let error: TestError
    init(error: TestError) { self.error = error; super.init() }

    override func load(loadConfig: LoadConfig<Int>) async -> LoadResult<Int, TestItem> {
        .failure(error)
    }
}

/// Source that serves pages normally except for a configured failing page,
/// which always returns `.failure`. Tracks per-page load call counts so tests
/// can assert that a failed load is (or isn't) re-attempted.
final class FailingOnPagePagingSource: PagingSource<Int, TestItem>, @unchecked Sendable {
    let totalPages: Int
    let pageSize: Int
    let failingPage: Int
    let error: TestError

    private let lock = NSLock()
    private var callCounts: [Int: Int] = [:]

    init(totalPages: Int, pageSize: Int, failingPage: Int, error: TestError) {
        self.totalPages = totalPages
        self.pageSize = pageSize
        self.failingPage = failingPage
        self.error = error
        super.init()
    }

    func loadCount(forPage page: Int) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return callCounts[page] ?? 0
    }

    override func load(loadConfig: LoadConfig<Int>) async -> LoadResult<Int, TestItem> {
        let page = loadConfig.key ?? 0
        lock.lock()
        callCounts[page, default: 0] += 1
        lock.unlock()

        if page == failingPage { return .failure(error) }
        guard (0..<totalPages).contains(page) else {
            return .page(items: [], previousKey: nil, nextKey: nil)
        }
        let start = page * pageSize
        let items = (0..<pageSize).map { TestItem(id: start + $0) }
        return .page(
            items: items,
            previousKey: page > 0 ? page - 1 : nil,
            nextKey: page + 1 < totalPages ? page + 1 : nil,
            itemsBefore: start,
            itemsAfter: (totalPages - page - 1) * pageSize
        )
    }
}

/// Source that reports `LoadResult.invalid` once, then serves pages normally.
final class FlakyInvalidatingSource: PagingSource<Int, TestItem>, @unchecked Sendable {
    private let lock = NSLock()
    private var hasReturnedInvalid = false

    override func load(loadConfig: LoadConfig<Int>) async -> LoadResult<Int, TestItem> {
        lock.lock()
        let shouldReturnInvalid = !hasReturnedInvalid
        hasReturnedInvalid = true
        lock.unlock()
        if shouldReturnInvalid { return .invalid }
        let page = loadConfig.key ?? 0
        let items = (0..<2).map { TestItem(id: page * 2 + $0) }
        return .page(items: items, previousKey: nil, nextKey: nil)
    }
}
