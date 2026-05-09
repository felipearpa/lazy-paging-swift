# lazy-paging-swift

A Swift Package that wraps a `PagingSource` in a SwiftUI `LazyVStack` with built-in loading, empty, error, and null-item placeholder states. It's the iOS counterpart to [`lazy-paging-kmp`](https://github.com/felipearpa/lazy-paging-kmp) and keeps the same API shape so behaviour stays in sync across platforms.

## Overview

`LazyPaging` exposes two SwiftUI views that consume a `LazyPagingItems<Key, Item>` and render the right UI for its current paging state:

- **`LazyPagingVStack`** — a `ScrollView` + `LazyVStack` that swaps between loading / empty / error / content slots, and renders a placeholder row for every position that is `nil`.
- **`RefreshableLazyPagingVStack`** — the same view wrapped in a native `.refreshable` modifier for pull-to-refresh.

State resolution is exposed via `LazyPagingVStackState` and computed by `resolveLazyPagingVStackState(refresh:prepend:append:itemCount:current:)`, so you only write UI for the state, not the paging-flag arithmetic.

## Placeholders

When a `PagingSource` returns a page it can report `itemsBefore` and `itemsAfter` counts: these are the number of not-yet-loaded items before and after the loaded window. `LazyPagingItems` uses those to size the list:

- `itemCount` = `itemsBefore + loadedItems.count + itemsAfter`
- `lazyPagingItems[index]` returns the loaded `Item` if it exists, or `nil` for a placeholder slot
- `lazyPagingItems.peek(at: index)` returns the same value without updating the anchor

The column iterates `0..<itemCount` and renders `itemContent(item)` for loaded slots and `placeholderContent()` for the `nil` ones. `ForEach` keys each loaded row by `Identifiable.id` and each placeholder by its position, so diffing stays stable as pages come in. Approaching an unloaded slot triggers the neighbouring page load automatically via `lazyPagingItems.onRowAccess(index:)` (which records the anchor and calls `appendIfNeeded` / `prependIfNeeded`).

Leave `itemsBefore` and `itemsAfter` as `0` (the default) if you don't know the total size — no placeholders are rendered, the list grows as pages stream in.

## Anchor-preserving refresh

On refresh, the pager calls `PagingSource.getRefreshKey(state:)` with a `PagingState` that carries the currently loaded pages, the config, and the user's last-visible `anchorPosition`. Override it to jump back to roughly where the user was — the default returns `nil`, which falls through to `Pager.initialKey`.

```swift
override func getRefreshKey(state: PagingState<Int, Item>) -> Int? {
    guard let anchor = state.anchorPosition,
          let page = state.closestPageToPosition(anchor) else { return nil }
    return page.previousKey.map { $0 + 1 } ?? page.nextKey.map { $0 - 1 }
}
```

## Platforms

- iOS 16+
- macOS 13+

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/felipearpa/lazy-paging-swift.git", from: "0.0.1"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "LazyPaging", package: "lazy-paging-swift"),
        ]
    )
]
```

Or in Xcode: **File → Add Package Dependencies…**

## Quick example

```swift
import SwiftUI
import LazyPaging

struct ItemsScreen: View {
    @StateObject private var lazyPagingItems: LazyPagingItems<Int, Item>

    init(pager: Pager<Int, Item>) {
        _lazyPagingItems = StateObject(wrappedValue: LazyPagingItems(pager: pager))
    }

    var body: some View {
        RefreshableLazyPagingVStack(
            lazyPagingItems: lazyPagingItems,
            loadingContent: { ProgressView() },
            emptyContent: { Text("Nothing here yet.") },
            errorContent: { error in
                VStack {
                    Text(error.localizedDescription)
                    Button("Retry") { Task { await lazyPagingItems.retry() } }
                }
            },
            placeholderContent: { PlaceholderRow() },
            itemContent: { item in ItemRow(item: item) }
        )
    }
}
```

Skip the `placeholderContent` argument if your source doesn't report placeholders — a default overload supplies `EmptyView` for every `nil` slot.

## Building a `PagingSource`

Subclass `PagingSource<Key, Item>`, implement `load`, and optionally override `getRefreshKey` for scroll-preserving refreshes. `LoadResult.page` carries cursors and the `itemsBefore` / `itemsAfter` placeholder counts; `.failure` surfaces through `LoadState`; `.invalid` tells the pager the in-flight result is stale and triggers a fresh refresh.

```swift
final class MyPagingSource: PagingSource<Int, Item>, @unchecked Sendable {
    override func load(loadConfig: LoadConfig<Int>) async -> LoadResult<Int, Item> {
        let page = loadConfig.key ?? 0
        do {
            let response = try await api.fetch(page: page, pageSize: loadConfig.loadSize)
            return .page(
                items: response.items,
                previousKey: page > 0 ? page - 1 : nil,
                nextKey: response.hasMore ? page + 1 : nil,
                itemsBefore: page * response.pageSize,
                itemsAfter: response.totalItems - (page + 1) * response.pageSize
            )
        } catch {
            return .failure(error as! (any Error & Sendable))
        }
    }

    override func getRefreshKey(state: PagingState<Int, Item>) -> Int? {
        state.anchorPosition.map { $0 / state.config.pageSize }
    }
}
```

Wrap it in a `Pager`:

```swift
let pager = Pager(
    config: PagingConfig(pageSize: 20, prefetchDistance: 10),
    pagingSourceFactory: { MyPagingSource() },
    initialKey: 0
)

let items = LazyPagingItems(pager: pager)
```

## Architecture

```
 LazyPagingVStack   RefreshableLazyPagingVStack   (SwiftUI)
         └─────────────────┬────────────────────┘
                           ▼
                   LazyPagingItems        (ObservableObject, @MainActor)
                           │
                           ▼
                      PageFetcher            (actor)
                           │
                           ▼
                      PagingSource           (overridable)
```

- `LazyPagingItems` is an `ObservableObject` (`@MainActor`) whose paging-state properties are `@Published`, so SwiftUI re-renders on state/item changes when the view holds the items via `@StateObject` / `@ObservedObject` / `@EnvironmentObject`.
- `PageFetcher` is an actor that owns the current `PagingSource` and the list of loaded `LoadedPage`s, making cursor advancement serial-by-construction.
- `InvalidateActionTracker` is also an actor, so invalidation is safe across threads.
- `PagingSource.load` is fully async and non-throwing (failures are returned as `LoadResult.failure`).
- `PagingSource.getRefreshKey(state:)` is overridable; the default returns `nil` (falls back to `Pager.initialKey`).

## AsyncStream pipeline + transformations

`Pager.stream` is an `AsyncStream<PagingData<Key, Item>>` that emits a fresh `PagingData` on subscribe and on every `PagingSource.invalidate()`.

```swift
for await pagingData in pager.stream {
    // handle a new paging session
}
```

`PagingData` is chainable:

```swift
let items = LazyPagingItems(
    pagingData: pager.pagingData()
        .map { item in Item(id: item.id, title: item.title.uppercased()) }
        .filter { $0.isEnabled }
        .insertSeparators { before, after -> DaySeparator? in
            guard let before, let after, before.day != after.day else { return nil }
            return DaySeparator(id: after.day.hashValue, heading: after.day)
        }
)
```

- `.map` preserves placeholders.
- `.filter` and `.insertSeparators` zero out `itemsBefore` / `itemsAfter` because they change per-page counts.
- `SeparatedItem<Item, Separator>` is `Identifiable` when both sides share an `ID` type, so it slots into `LazyPagingVStack` without extra wiring.

## `maxSize` (page dropping)

Set `maxSize` on `PagingConfig` to cap how many items stay in memory:

```swift
Pager(
    config: PagingConfig(pageSize: 20, prefetchDistance: 10, maxSize: 80),
    ...
)
```

After a successful **append**, pages are dropped from the **head** until the total is within `maxSize`; after a successful **prepend**, pages are dropped from the **tail**. Dropped ranges reappear as placeholders (`itemsBefore` / `itemsAfter` are bumped) and the opposite direction's `endOfPaginationReached` is cleared so the dropped pages can be re-fetched on scroll back.

`maxSize` must be at least `pageSize * 2 + prefetchDistance` — caught by an assertion at `PagingConfig.init` to stop you shipping a thrashing config.

## `RemoteMediator` (network + local cache)

A `RemoteMediator<Key, Item>` coordinates a network layer with a local `PagingSource` that reads from an on-device store. The library stays storage-agnostic: wire both the mediator and the source to the same store (SwiftData, Core Data, an in-memory array, …).

```swift
final class MyMediator: RemoteMediator {
    typealias Key = Int
    typealias Item = Article

    let api: Api
    let store: Store

    func initialize() async -> InitializeAction { .launchInitialRefresh }

    func load(loadType: LoadType, state: PagingState<Int, Article>) async -> MediatorResult {
        do {
            let response = try await api.fetch(page: loadType == .refresh ? 0 : state.pages.last?.nextKey ?? 0)
            await store.write(response.items, replace: loadType == .refresh)
            return .success(endOfPaginationReached: !response.hasMore)
        } catch {
            return .failure(error as! (any Error & Sendable))
        }
    }
}

let pager = Pager<Int, Article>(
    config: PagingConfig(pageSize: 20),
    remoteMediator: MyMediator(api: api, store: store),
    pagingSourceFactory: { StoreBackedSource(store: store) },
    initialKey: 0
)
```

- **Refresh**: mediator runs first (unless `initialize()` returns `.skipInitialRefresh`), then the source reads from the freshly-written store.
- **Append** / **prepend**: the mediator is called only when the local source reports end-of-pagination in that direction — i.e. the store is exhausted. On success, the source is invalidated and the UI re-reads from the store.
- **`CombinedLoadStates.mediator`** and **`.source`** expose per-layer triples so you can surface "loading from network" vs "loading from local" separately. Top-level `refresh` / `prepend` / `append` aggregate the two (failure ≻ loading ≻ idle).

## Showcase

A runnable showcase lives in `Sources/LazyPagingShowcase/` (the scenarios + screen) and `Sources/LazyPagingShowcaseApp/` (the macOS SwiftUI launcher). It exercises:

- **Bidirectional** — starts in the middle of 20 pages, scroll up or down and watch placeholders on both ends resolve into items.
- **Forward only** — starts at page 0, append more pages.
- **Empty result** — source returns zero items.
- **Initial load error** — refresh fails.
- **Append error at page 2** — pages 0–1 load, page 2 errors.
- **Prepend error at page 9** — scrolling up triggers a prepend failure.
- **Slow network** — long delays to inspect placeholder and loading states.

Run it with:

```bash
swift run LazyPagingShowcaseApp
```

For iOS, add the `LazyPagingShowcase` library to an iOS Xcode project and present `ShowcaseScreen()`.

## License

MIT.
