# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.0.1] - 2026-05-10
### Initial Release
- **`LazyPagingVStack`** — SwiftUI `ScrollView`/`LazyVStack` that consumes `LazyPagingItems<Key, Item>` and renders dedicated slots for loading, empty, error, and content states, plus a `placeholderContent` slot rendered for every position where `lazyPagingItems[index]` is `nil`.
- **`RefreshableLazyPagingVStack`** — wraps `LazyPagingVStack` in the native `.refreshable` pull-to-refresh modifier.
- **`LazyPagingVStackState`** with `.loading`, `.empty`, `.error`, and `.content` cases, plus `resolveLazyPagingVStackState(refresh:prepend:append:itemCount:current:)`.
- **`LazyPagingItems`** — an `ObservableObject`/`@MainActor` holder that drives refresh, prepend, and append load states. Exposes `onRowAccess(index:)` for prefetch + anchor tracking, `appendIfNeeded(currentIndex:)` / `prependIfNeeded(currentIndex:)` helpers, `retry()`, `peek(at:)`, `anchorPosition`, and a `subscript(_:)` that returns `Item?` (`nil` for placeholder slots). Stable `ForEach` identity in `LazyPagingVStack`: loaded rows keyed by `item.id`, placeholder rows keyed by position.
- **Actor-based `PageFetcher` and `InvalidateActionTracker`** for thread-safe cursor advancement and invalidation.
- **`PagingSource<Key, Item>`** with `LoadConfig` (carrying `key` and `loadSize`), `LoadResult.page` (carrying `items`, optional `previousKey` / `nextKey`, and `itemsBefore` / `itemsAfter` placeholder counts), `LoadResult.failure`, and `LoadResult.invalid` — when a source invalidates mid-load, `LazyPagingItems` discards the in-flight result and triggers a fresh refresh.
- **`PagingSource.getRefreshKey(state:)`** — overridable for anchor-preserving refresh; default returns `nil` (falls back to `Pager.initialKey`).
- **`PagingState<Key, Item>`** with `pages`, `anchorPosition`, `config`, and `leadingPlaceholderCount`; exposes `closestPageToPosition(_:)` and `closestItemToPosition(_:)`.
- **`LoadedPage<Key, Item>`** exposed publicly so sources can inspect loaded pages via `PagingState`.
- **`Pager`** with **`PagingConfig`** (`pageSize`, `initialLoadSize`, `prefetchDistance` defaulting to `pageSize`, optional `maxSize`).
- **`maxSize` page dropping.** After a successful append, pages are dropped from the head; after a successful prepend, from the tail; until total items ≤ `maxSize`. Dropped ranges reappear as placeholder slots (`itemsBefore` / `itemsAfter` are bumped) and the opposite direction's `endOfPaginationReached` is cleared so dropped pages can be re-fetched on scroll back. `maxSize` must be at least `pageSize * 2 + prefetchDistance` (asserted at init).
- **`AsyncStream` pipeline.** `Pager.stream: AsyncStream<PagingData<Key, Item>>` emits a fresh `PagingData` on subscribe and on every `PagingSource.invalidate()`; `Pager.pagingData()` returns a single session snapshot; cancellation propagates through `onTermination` so no tasks leak.
- **`PagingData<Key, Item>`** — opaque snapshot (`PagingSource` + config + `initialKey`) with chainable transformations:
  - `.map<NewItem>(_:)` — preserves `itemsBefore` / `itemsAfter` (item count per page is unchanged).
  - `.filter(_:)` — drops placeholder counts because filtering changes per-page counts.
  - `.insertSeparators<Separator>(_:)` — injects `SeparatedItem<Item, Separator>` between items, with leading-edge support; `SeparatedItem` is `Identifiable` when both sides share an `ID`.
- **`LazyPagingItems.init(pagingData:)`** as the primary init; `init(pager:)` is a convenience that routes through `pager.pagingData()`.
- **`RemoteMediator<Key, Item>`** for network + local-store coordination, plus `LoadType` (`.refresh` / `.prepend` / `.append`), `MediatorResult` (`.success(endOfPaginationReached:)` / `.failure`), and `InitializeAction` (`.launchInitialRefresh` / `.skipInitialRefresh`, default `.launchInitialRefresh`). `Pager` accepts an optional `remoteMediator`; `LazyPagingItems` runs mediator refresh before source refresh (unless `initialize()` returns `.skipInitialRefresh`), and runs mediator append / prepend when the source reaches end-of-pagination in that direction; mediator success invalidates the source for a fresh read.
- **`LoadStates`** struct (triple of `LoadState`) and **`CombinedLoadStates`** with `.source` and `.mediator` fields. Top-level `refresh` / `prepend` / `append` aggregate across layers (failure ≻ loading ≻ idle).
- **`LazyPagingShowcase` library + `LazyPagingShowcaseApp` executable** covering bidirectional, forward-only, empty, initial error, append error, prepend error, and slow network scenarios, with shimmering placeholder rows.
- **Tests**: `PagingStateTests`, `MaxSizeTests`, `StreamTests`, `RemoteMediatorTests`.
