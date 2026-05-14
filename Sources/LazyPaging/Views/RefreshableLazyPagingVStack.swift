import SwiftUI

/// ``LazyPagingVStack`` wrapped in a native `.refreshable` modifier so users
/// can pull the list down to trigger a refresh. Mirrors the KMP
/// `RefreshableLazyPagingColumn` composable.
public struct RefreshableLazyPagingVStack<
    Key: Hashable & Sendable,
    Item: Identifiable & Hashable & Sendable,
    LoadingContent: View,
    EmptyContent: View,
    ErrorContent: View,
    PrependLoadingContent: View,
    AppendLoadingContent: View,
    PrependErrorContent: View,
    AppendErrorContent: View,
    RowContent: View
>: View {
    @ObservedObject private var lazyPagingItems: LazyPagingItems<Key, Item>

    private let spacing: CGFloat
    private let contentInsets: EdgeInsets
    private let pinnedViews: PinnedScrollableViews

    private let loadingContent: () -> LoadingContent
    private let emptyContent: () -> EmptyContent
    private let errorContent: (any Error) -> ErrorContent
    private let prependLoadingContent: () -> PrependLoadingContent
    private let appendLoadingContent: () -> AppendLoadingContent
    private let prependErrorContent: (any Error) -> PrependErrorContent
    private let appendErrorContent: (any Error) -> AppendErrorContent
    private let rowContent: (Int) -> RowContent

    public init(
        lazyPagingItems: LazyPagingItems<Key, Item>,
        spacing: CGFloat = 0,
        contentInsets: EdgeInsets = EdgeInsets(),
        pinnedViews: PinnedScrollableViews = [],
        @ViewBuilder loadingContent: @escaping () -> LoadingContent,
        @ViewBuilder emptyContent: @escaping () -> EmptyContent,
        @ViewBuilder errorContent: @escaping (any Error) -> ErrorContent,
        @ViewBuilder prependLoadingContent: @escaping () -> PrependLoadingContent,
        @ViewBuilder appendLoadingContent: @escaping () -> AppendLoadingContent,
        @ViewBuilder prependErrorContent: @escaping (any Error) -> PrependErrorContent,
        @ViewBuilder appendErrorContent: @escaping (any Error) -> AppendErrorContent,
        @ViewBuilder rowContent: @escaping (Int) -> RowContent
    ) {
        self._lazyPagingItems = ObservedObject(wrappedValue: lazyPagingItems)
        self.spacing = spacing
        self.contentInsets = contentInsets
        self.pinnedViews = pinnedViews
        self.loadingContent = loadingContent
        self.emptyContent = emptyContent
        self.errorContent = errorContent
        self.prependLoadingContent = prependLoadingContent
        self.appendLoadingContent = appendLoadingContent
        self.prependErrorContent = prependErrorContent
        self.appendErrorContent = appendErrorContent
        self.rowContent = rowContent
    }

    /// Convenience init for callers that don't customise the prepend/append
    /// slots — the four new slots default to `EmptyView`. Intended for sources
    /// that report `itemsBefore`/`itemsAfter` placeholders so the placeholder
    /// row itself can carry any loading/error affordance.
    public init(
        lazyPagingItems: LazyPagingItems<Key, Item>,
        spacing: CGFloat = 0,
        contentInsets: EdgeInsets = EdgeInsets(),
        pinnedViews: PinnedScrollableViews = [],
        @ViewBuilder loadingContent: @escaping () -> LoadingContent,
        @ViewBuilder emptyContent: @escaping () -> EmptyContent,
        @ViewBuilder errorContent: @escaping (any Error) -> ErrorContent,
        @ViewBuilder rowContent: @escaping (Int) -> RowContent
    ) where
        PrependLoadingContent == EmptyView,
        AppendLoadingContent == EmptyView,
        PrependErrorContent == EmptyView,
        AppendErrorContent == EmptyView
    {
        self.init(
            lazyPagingItems: lazyPagingItems,
            spacing: spacing,
            contentInsets: contentInsets,
            pinnedViews: pinnedViews,
            loadingContent: loadingContent,
            emptyContent: emptyContent,
            errorContent: errorContent,
            prependLoadingContent: { EmptyView() },
            appendLoadingContent: { EmptyView() },
            prependErrorContent: { _ in EmptyView() },
            appendErrorContent: { _ in EmptyView() },
            rowContent: rowContent
        )
    }

    public var body: some View {
        LazyPagingVStack(
            lazyPagingItems: lazyPagingItems,
            spacing: spacing,
            contentInsets: contentInsets,
            pinnedViews: pinnedViews,
            loadingContent: loadingContent,
            emptyContent: emptyContent,
            errorContent: errorContent,
            prependLoadingContent: prependLoadingContent,
            appendLoadingContent: appendLoadingContent,
            prependErrorContent: prependErrorContent,
            appendErrorContent: appendErrorContent,
            rowContent: rowContent
        )
        .refreshable { await lazyPagingItems.refresh() }
    }
}
