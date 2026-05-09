import SwiftUI

/// A `LazyVStack` wrapped in a `ScrollView` that swaps between loading,
/// empty, error, and content slots based on a ``LazyPagingItems`` stream.
///
/// Mirrors the AndroidX / KMP Paging `items(count:key:contentType:)` block:
/// callers iterate ``LazyPagingItems/itemCount`` positions through a single
/// row closure that receives the index and decides whether to render an
/// item view or a placeholder based on `lazyPagingItems[index]`.
///
/// Row identity follows AndroidX's `itemKey` pattern: loaded rows are keyed
/// by `Identifiable.id`, placeholder rows by a synthesised key tied to the
/// position. Approaching an unloaded slot automatically triggers the
/// neighbouring page load through ``LazyPagingItems/onRowAccess(index:)``,
/// which also stores the anchor position for
/// ``PagingSource/getRefreshKey(state:)`` to use on refresh.
public struct LazyPagingVStack<
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

    // Drives the initial-key scroll jump. Set inside `.task` after refresh
    // completes; consumed by `.onChange` so the actual `proxy.scrollTo`
    // call runs *after* SwiftUI has rendered the loaded rows into the
    // `LazyVStack` — calling it synchronously inside `.task` is a no-op
    // because the target row isn't in the view tree yet.
    @State private var initialScrollTarget: AnyHashable?

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
        // Derive the "previous state" hint from itemCount rather than
        // hard-coding `.content`: before the first refresh completes there
        // are no items, and the resolver's reload-preservation branch would
        // otherwise render the empty content area during the initial load
        // and hide the loading view entirely.
        let currentHint: LazyPagingVStackState = lazyPagingItems.itemCount > 0 ? .content : .loading
        let columnState = resolveLazyPagingVStackState(
            refresh: lazyPagingItems.loadState.refresh,
            prepend: lazyPagingItems.loadState.prepend,
            append: lazyPagingItems.loadState.append,
            itemCount: lazyPagingItems.itemCount,
            current: currentHint
        )

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: spacing, pinnedViews: pinnedViews) {
                    switch columnState {
                    case .loading:
                        loadingContent()
                    case .empty:
                        emptyContent()
                    case .error(let error):
                        errorContent(error)
                    case .content:
                        itemsContent
                    }
                }
                .padding(contentInsets)
            }
            // Keyed on the items instance so the refresh re-fires when the
            // caller swaps in a fresh `LazyPagingItems`. Without the id,
            // SwiftUI only runs `.task` once per view-appearance and the
            // new instance stays stuck on the loading state.
            .task(id: ObjectIdentifier(lazyPagingItems)) {
                initialScrollTarget = nil
                await lazyPagingItems.refresh()
                // When the initial key sits in the middle of the dataset the
                // source reports leading placeholders and the content starts
                // far below the default scroll offset. Jumping the viewport
                // onto the first loaded row lets prefetch radiate outward from
                // the anchor — same behaviour as AndroidX Paging's initial key.
                if lazyPagingItems.itemsBefore > 0,
                   let first = lazyPagingItems.loadedItems.first {
                    initialScrollTarget = AnyHashable(first.id)
                }
            }
            .onChange(of: initialScrollTarget) { target in
                guard let target else { return }
                proxy.scrollTo(target, anchor: .top)
            }
        }
    }

    @ViewBuilder private var itemsContent: some View {
        ForEach(pagedRows) { row in
            rowContent(row.index)
                .task { await lazyPagingItems.onRowAccess(index: row.index) }
        }
    }

    private var pagedRows: [PagedRow<Item>] {
        (0..<lazyPagingItems.itemCount).map { index in
            PagedRow(index: index, item: lazyPagingItems.peek(at: index))
        }
    }
}

/// Row projection used by ``LazyPagingVStack``. Loaded rows use their
/// `Identifiable.id`; placeholder rows get a synthesised key tied to the
/// position so the `ForEach` diff is stable as pages stream in — mirrors
/// AndroidX's `LazyPagingItems.itemKey` fallback.
private struct PagedRow<Item: Identifiable & Hashable>: Identifiable {
    let index: Int
    let item: Item?

    var id: AnyHashable {
        if let item { return AnyHashable(item.id) }
        return AnyHashable("_lazy_paging_placeholder_\(index)")
    }
}
