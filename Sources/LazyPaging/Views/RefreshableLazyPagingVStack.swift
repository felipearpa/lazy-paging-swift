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
    RowContent: View
>: View {
    @ObservedObject private var lazyPagingItems: LazyPagingItems<Key, Item>

    private let spacing: CGFloat
    private let contentInsets: EdgeInsets
    private let pinnedViews: PinnedScrollableViews

    private let loadingContent: () -> LoadingContent
    private let emptyContent: () -> EmptyContent
    private let errorContent: (any Error) -> ErrorContent
    private let rowContent: (Int) -> RowContent

    public init(
        lazyPagingItems: LazyPagingItems<Key, Item>,
        spacing: CGFloat = 0,
        contentInsets: EdgeInsets = EdgeInsets(),
        pinnedViews: PinnedScrollableViews = [],
        @ViewBuilder loadingContent: @escaping () -> LoadingContent,
        @ViewBuilder emptyContent: @escaping () -> EmptyContent,
        @ViewBuilder errorContent: @escaping (any Error) -> ErrorContent,
        @ViewBuilder rowContent: @escaping (Int) -> RowContent
    ) {
        self._lazyPagingItems = ObservedObject(wrappedValue: lazyPagingItems)
        self.spacing = spacing
        self.contentInsets = contentInsets
        self.pinnedViews = pinnedViews
        self.loadingContent = loadingContent
        self.emptyContent = emptyContent
        self.errorContent = errorContent
        self.rowContent = rowContent
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
            rowContent: rowContent
        )
        .refreshable { await lazyPagingItems.refresh() }
    }
}
