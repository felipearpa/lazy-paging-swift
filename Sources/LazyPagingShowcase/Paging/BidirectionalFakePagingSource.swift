import Foundation
import LazyPaging

/// In-memory paging source that mirrors the KMP sample `BidirectionalFakePagingSource`.
///
/// Pages are indexed 0..<totalPages and loaded through simulated latency. The
/// flags below let the showcase reproduce every edge case the KMP sample shows.
/// The source also reports `itemsBefore` and `itemsAfter` counts so the
/// column can render placeholder rows for positions that have not yet been
/// loaded — the AndroidX Paging placeholder model.
public final class BidirectionalFakePagingSource: PagingSource<Int, SampleItem>, @unchecked Sendable {
    private let totalItems: Int
    private let pageSize: Int
    private let loadDelayNanos: UInt64
    private let refreshDelayNanos: UInt64
    private let emptyResult: Bool
    private let failOnRefresh: Bool
    private let failOnAppendPage: Int?
    private let failOnPrependPage: Int?
    private let disablePlaceholders: Bool

    public init(
        totalItems: Int,
        pageSize: Int,
        loadDelayMillis: UInt64,
        refreshDelayMillis: UInt64,
        emptyResult: Bool,
        failOnRefresh: Bool,
        failOnAppendPage: Int?,
        failOnPrependPage: Int?,
        disablePlaceholders: Bool = false
    ) {
        self.totalItems = totalItems
        self.pageSize = pageSize
        self.loadDelayNanos = loadDelayMillis * NSEC_PER_MSEC
        self.refreshDelayNanos = refreshDelayMillis * NSEC_PER_MSEC
        self.emptyResult = emptyResult
        self.failOnRefresh = failOnRefresh
        self.failOnAppendPage = failOnAppendPage
        self.failOnPrependPage = failOnPrependPage
        self.disablePlaceholders = disablePlaceholders
    }

    /// Preserves scroll position on refresh: jumps back to the page closest
    /// to the user's current anchor, matching AndroidX Paging's typical
    /// `getRefreshKey` pattern.
    public override func getRefreshKey(state: PagingState<Int, SampleItem>) -> Int? {
        guard let anchor = state.anchorPosition else { return nil }
        return anchor / pageSize
    }

    public override func load(
        loadConfig: LoadConfig<Int>
    ) async -> LoadResult<Int, SampleItem> {
        let pageIndex = loadConfig.key ?? 0

        switch loadConfig.kind {
        case .refresh:
            try? await Task.sleep(nanoseconds: refreshDelayNanos)
        case .prepend, .append:
            try? await Task.sleep(nanoseconds: loadDelayNanos)
        }

        if loadConfig.kind == .refresh, failOnRefresh {
            return .failure(PagingDemoError("Refresh failed (simulated)"))
        }
        if loadConfig.kind == .append, failOnAppendPage == pageIndex {
            return .failure(PagingDemoError("Append failed on page \(pageIndex) (simulated)"))
        }
        if loadConfig.kind == .prepend, failOnPrependPage == pageIndex {
            return .failure(PagingDemoError("Prepend failed on page \(pageIndex) (simulated)"))
        }

        if emptyResult {
            return .page(items: [], previousKey: nil, nextKey: nil)
        }

        let totalPages = (totalItems + pageSize - 1) / pageSize
        guard (0..<totalPages).contains(pageIndex) else {
            return .page(items: [], previousKey: nil, nextKey: nil)
        }

        let startIndex = pageIndex * pageSize
        let endIndex = min(startIndex + pageSize, totalItems)
        let items = (startIndex..<endIndex).map { index in
            SampleItem(id: index, label: "Item #\(index)")
        }

        return .page(
            items: items,
            previousKey: pageIndex > 0 ? pageIndex - 1 : nil,
            nextKey: pageIndex + 1 < totalPages ? pageIndex + 1 : nil,
            itemsBefore: disablePlaceholders ? 0 : startIndex,
            itemsAfter: disablePlaceholders ? 0 : totalItems - endIndex
        )
    }
}

public struct PagingDemoError: LocalizedError, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}
