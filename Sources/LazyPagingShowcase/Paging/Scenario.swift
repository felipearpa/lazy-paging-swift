import Foundation
import LazyPaging

public enum Scenario: String, CaseIterable, Identifiable, Sendable {
    case bidirectional
    case forwardOnly
    case empty
    case initialError
    case appendError
    case prependError
    case slow
    case stickyHeaders
    case withoutPlaceholders

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .bidirectional: "Bidirectional"
        case .forwardOnly: "Forward only"
        case .empty: "Empty result"
        case .initialError: "Initial load error"
        case .appendError: "Append error at page 2"
        case .prependError: "Prepend error at page 9"
        case .slow: "Slow network"
        case .stickyHeaders: "Sticky headers"
        case .withoutPlaceholders: "Without placeholders (forward only)"
        }
    }

    public var summary: String {
        switch self {
        case .bidirectional:
            "Starts at page 10 of 20. Scroll up to prepend, down to append."
        case .forwardOnly:
            "Starts at page 0. Scroll down to append more pages."
        case .empty:
            "Source returns zero items — shows the Empty state."
        case .initialError:
            "Refresh fails — shows the Error state."
        case .appendError:
            "Pages 0–1 load; page 2 errors. Tests inline append failure handling."
        case .prependError:
            "Starts at page 10; scrolling up triggers a prepend failure at page 9."
        case .slow:
            "Long delays on refresh and page loads to inspect loading states."
        case .stickyHeaders:
            "Bidirectional data grouped into 10-item buckets — group headers stay pinned while any row of the bucket is visible."
        case .withoutPlaceholders:
            "Forward-only feed starting at page 0. The source reports no itemsBefore/itemsAfter, so the list ends at the last loaded row and the append loading/error slot params carry the affordance instead of a placeholder row."
        }
    }

    /// `true` when this scenario's source reports zero placeholders. The
    /// showcase wires the prepend/append slot params for these scenarios so
    /// the column boundary still shows a loading / retry affordance.
    public var disablesPlaceholders: Bool {
        if case .withoutPlaceholders = self { return true }
        return false
    }

    /// Page-load latency. `.withoutPlaceholders` slows pages so the append
    /// loading footer stays on screen long enough to observe — at 600ms the
    /// prefetch lands while the user is still scrolling toward the boundary,
    /// and the footer disappears before it ever enters the viewport.
    var loadDelayMillis: UInt64 {
        switch self {
        case .slow: 2_000
        case .withoutPlaceholders: 1_500
        default: 600
        }
    }

    var refreshDelayMillis: UInt64 {
        switch self {
        case .slow: 3_000
        default: 900
        }
    }

    /// Per-scenario prefetch distance. `.withoutPlaceholders` shrinks the
    /// window so the append load fires only as the user reaches the actual
    /// last loaded row — otherwise the prefetch lands while the loading
    /// footer is still offscreen and the user never sees it.
    var prefetchDistance: Int {
        switch self {
        case .withoutPlaceholders: 0
        default: ScenarioConstants.pageSize / 2
        }
    }

    /// Switches the showcase rendering between the standard column and the
    /// caller-side sticky-headers view. Other scenarios drive only data
    /// behaviour, so they default to the standard column.
    public var usesStickyHeaders: Bool {
        if case .stickyHeaders = self { return true }
        return false
    }
}

private enum ScenarioConstants {
    static let pageSize = 20
    static let totalItems = 400
    static let middlePage = 10
}

public extension Scenario {
    func pager() -> Pager<Int, SampleItem> {
        let config = PagingConfig(
            pageSize: ScenarioConstants.pageSize,
            prefetchDistance: prefetchDistance
        )
        let scenario = self
        return Pager(
            config: config,
            pagingSourceFactory: {
                BidirectionalFakePagingSource(
                    totalItems: scenario == .empty ? 0 : ScenarioConstants.totalItems,
                    pageSize: ScenarioConstants.pageSize,
                    loadDelayMillis: scenario.loadDelayMillis,
                    refreshDelayMillis: scenario.refreshDelayMillis,
                    emptyResult: scenario == .empty,
                    failOnRefresh: scenario == .initialError,
                    failOnAppendPage: scenario == .appendError ? 2 : nil,
                    failOnPrependPage: scenario == .prependError ? 9 : nil,
                    disablePlaceholders: scenario.disablesPlaceholders
                )
            },
            initialKey: initialKey
        )
    }

    private var initialKey: Int {
        switch self {
        case .bidirectional, .prependError, .stickyHeaders: ScenarioConstants.middlePage
        default: 0
        }
    }
}
