import Foundation
import Combine

/// Observable holder that streams items from a ``Pager`` into SwiftUI.
///
/// Behaviour follows AndroidX Paging / the KMP `LazyPagingItems`:
///
/// - three independent load states (refresh / prepend / append) drive the UI,
///   each layered into ``CombinedLoadStates/source`` and
///   ``CombinedLoadStates/mediator`` so consumers can tell which layer is
///   currently loading or failing
/// - ``itemCount`` reports loaded items plus any placeholder slots the source
///   reported via `itemsBefore` / `itemsAfter`
/// - ``subscript(_:)`` returns `nil` for a placeholder slot that has not been
///   loaded yet, and the loaded `Item` otherwise — the UI renders a
///   placeholder row for the `nil` positions
/// - ``peek(at:)`` reads a position without updating the anchor or triggering
///   neighbouring loads
/// - the column feeds visible indices through ``onRowAccess(index:)``; the
///   index is stored as the anchor so a ``PagingSource/getRefreshKey(state:)``
///   override can preserve scroll position on refresh
///
/// When the owning ``Pager`` carries a ``RemoteMediator``, this class
/// coordinates the mediator with the local source: mediator refresh runs
/// before source refresh (unless the mediator's
/// ``RemoteMediator/initialize()`` returns
/// ``InitializeAction/skipInitialRefresh``), and mediator append/prepend
/// runs when the source reaches end-of-pagination in that direction.
///
/// All public state is updated on the main actor; cursor advancement happens
/// inside the underlying ``PageFetcher`` actor.
@MainActor
public final class LazyPagingItems<Key: Hashable & Sendable, Item: Identifiable & Hashable & Sendable>: ObservableObject {
    @Published public private(set) var loadState: CombinedLoadStates = .idle
    @Published public private(set) var loadedItems: [Item] = []
    @Published public private(set) var itemsBefore: Int = 0
    @Published public private(set) var itemsAfter: Int = 0
    // Not `@Published`: `subscript(_:)` writes this on every read during row
    // rendering. Publishing it would fire `objectWillChange` mid-render and
    // re-invalidate the view in a tight loop. The UI never reads
    // `anchorPosition` directly — it's an internal hint for refresh keying —
    // so leaving it off `@Published` is correct as well as load-bearing.
    public private(set) var anchorPosition: Int?

    private let pager: Pager<Key, Item>
    private let pageFetcher: PageFetcher<Key, Item>
    private var invalidateActionId: UUID?
    private var retryAction: (@Sendable () async -> Void)?
    private var mediatorInitialized: Bool = false
    private var mediatorInitializeAction: InitializeAction = .launchInitialRefresh

    public convenience init(pager: Pager<Key, Item>) {
        self.init(pagingData: pager.pagingData())
    }

    public init(pagingData: PagingData<Key, Item>) {
        self.pager = pagingData.pager
        self.pageFetcher = PageFetcher(pager: pagingData.pager, source: pagingData.source)

        if pager.remoteMediator != nil {
            // Surface a non-nil mediator triple right away so the UI can
            // distinguish "no mediator" from "mediator idle".
            self.loadState = CombinedLoadStates(
                refresh: .notLoading(endOfPaginationReached: false),
                prepend: .notLoading(endOfPaginationReached: false),
                append: .notLoading(endOfPaginationReached: false),
                source: .idle,
                mediator: .idle
            )
        }

        let source = pagingData.source
        Task { [weak self] in
            let id = await source.registerInvalidateAction { [weak self] in
                await self?.refresh()
            }
            await MainActor.run { [weak self] in
                self?.invalidateActionId = id
            }
        }
    }

    // MARK: Counts

    public var itemCount: Int { itemsBefore + loadedItems.count + itemsAfter }
    public var isEmpty: Bool { itemCount == 0 }
    public var isNotEmpty: Bool { itemCount > 0 }

    public subscript(index: Int) -> Item? {
        anchorPosition = index
        return peek(at: index)
    }

    public func peek(at index: Int) -> Item? {
        guard index >= itemsBefore else { return nil }
        let offset = index - itemsBefore
        guard offset < loadedItems.count else { return nil }
        return loadedItems[offset]
    }

    // MARK: Public API

    public func refresh() async {
        retryAction = { [weak self] in
            await self?.refresh()
        }

        // Initialise the mediator on first refresh so we can honour
        // `skipInitialRefresh`.
        if let mediator = pager.remoteMediator, !mediatorInitialized {
            mediatorInitializeAction = await mediator.initialize()
            mediatorInitialized = true
        }

        // Stage 1: mediator refresh (if applicable).
        if let mediator = pager.remoteMediator,
           mediatorInitializeAction == .launchInitialRefresh {
            setMediatorLoading(.refresh)
            let state = makePagingState()
            switch await mediator.load(loadType: .refresh, state: state) {
            case .success(let eop):
                setMediatorNotLoading(.refresh, endOfPaginationReached: eop)
            case .failure(let error):
                setMediatorFailure(.refresh, error: error)
                return
            }
        }

        // Stage 2: source refresh.
        setSourceLoading(.refresh)
        let result = await pageFetcher.refresh(
            anchorPosition: anchorPosition,
            itemsBefore: itemsBefore
        )
        apply(result: result, kind: .refresh)
    }

    public func refreshWithoutNotification() async {
        _ = await pageFetcher.refresh(
            anchorPosition: anchorPosition,
            itemsBefore: itemsBefore
        )
    }

    public func onRowAccess(index: Int) async {
        anchorPosition = index
        await appendIfNeeded(currentIndex: index)
        await prependIfNeeded(currentIndex: index)
    }

    public func appendIfNeeded(currentIndex: Int) async {
        guard isAppendNeeded(currentIndex: currentIndex) else { return }
        // Stop auto-retrying after a failure so row-task triggers don't loop
        // on a deterministic error. Matches AndroidX Paging: explicit retry()
        // is required to attempt the load again.
        if loadState.append.isFailure { return }
        retryAction = { [weak self] in await self?.append() }
        await append()
    }

    public func prependIfNeeded(currentIndex: Int) async {
        guard isPrependNeeded(currentIndex: currentIndex) else { return }
        if loadState.prepend.isFailure { return }
        retryAction = { [weak self] in await self?.prepend() }
        await prepend()
    }

    public func retry() async {
        guard let retryAction else { return }
        await retryAction()
    }

    // MARK: Prefetch heuristics

    private func isAppendNeeded(currentIndex: Int) -> Bool {
        guard !loadedItems.isEmpty else { return false }
        let distance = pager.config.prefetchDistance
        let lastLoadedIndex = itemsBefore + loadedItems.count - 1
        return currentIndex >= lastLoadedIndex - distance
    }

    private func isPrependNeeded(currentIndex: Int) -> Bool {
        guard !loadedItems.isEmpty else { return false }
        let distance = pager.config.prefetchDistance
        let firstLoadedIndex = itemsBefore
        return currentIndex <= firstLoadedIndex + distance
    }

    // MARK: Load orchestration

    private func append() async {
        guard !loadState.refresh.isLoading else { return }
        guard !loadState.append.isLoading else { return }

        let sourceCanAppend = await pageFetcher.canAppend()

        if sourceCanAppend {
            setSourceLoading(.append)
            if let result = await pageFetcher.append() {
                apply(result: result, kind: .append)
            }
            return
        }

        // Source is at end-of-pagination for append. Delegate to mediator.
        guard let mediator = pager.remoteMediator else { return }
        guard !(loadState.mediator?.append.endOfPaginationReached ?? false) else { return }

        setMediatorLoading(.append)
        let state = makePagingState()
        switch await mediator.load(loadType: .append, state: state) {
        case .success(let eop):
            setMediatorNotLoading(.append, endOfPaginationReached: eop)
            // Mediator wrote more to the store; invalidating the source
            // triggers a full refresh that will read the new data.
            if !eop { await refresh() }
        case .failure(let error):
            setMediatorFailure(.append, error: error)
        }
    }

    private func prepend() async {
        guard !loadState.refresh.isLoading else { return }
        guard !loadState.prepend.isLoading else { return }

        let sourceCanPrepend = await pageFetcher.canPrepend()

        if sourceCanPrepend {
            setSourceLoading(.prepend)
            if let result = await pageFetcher.prepend() {
                apply(result: result, kind: .prepend)
            }
            return
        }

        guard let mediator = pager.remoteMediator else { return }
        guard !(loadState.mediator?.prepend.endOfPaginationReached ?? false) else { return }

        setMediatorLoading(.prepend)
        let state = makePagingState()
        switch await mediator.load(loadType: .prepend, state: state) {
        case .success(let eop):
            setMediatorNotLoading(.prepend, endOfPaginationReached: eop)
            if !eop { await refresh() }
        case .failure(let error):
            setMediatorFailure(.prepend, error: error)
        }
    }

    // MARK: Result fan-out

    private enum Kind { case refresh, prepend, append }

    private func apply(result: FetchResult<Key, Item>, kind: Kind) {
        switch result {
        case .page(
            let newItems,
            let previousKey,
            let nextKey,
            let newItemsBefore,
            let newItemsAfter,
            let droppedFromHead,
            let droppedFromTail
        ):
            switch kind {
            case .refresh:
                loadedItems = newItems
                itemsBefore = newItemsBefore
                itemsAfter = newItemsAfter
                setSourceNotLoading(
                    refreshEOP: previousKey == nil && nextKey == nil,
                    prependEOP: previousKey == nil,
                    appendEOP: nextKey == nil
                )
            case .prepend:
                loadedItems = newItems + loadedItems
                itemsBefore = newItemsBefore
                if droppedFromTail > 0 {
                    loadedItems.removeLast(droppedFromTail)
                    itemsAfter += droppedFromTail
                }
                setSourcePrependNotLoading(
                    prependEOP: previousKey == nil,
                    appendEOP: droppedFromTail > 0 ? false : nil
                )
            case .append:
                loadedItems = loadedItems + newItems
                itemsAfter = newItemsAfter
                if droppedFromHead > 0 {
                    loadedItems.removeFirst(droppedFromHead)
                    itemsBefore += droppedFromHead
                }
                setSourceAppendNotLoading(
                    appendEOP: nextKey == nil,
                    prependEOP: droppedFromHead > 0 ? false : nil
                )
            }

        case .failure(let error):
            setSourceFailure(kind, error: error)

        case .invalid:
            Task { [weak self] in await self?.refresh() }
        }
    }

    private func makePagingState() -> PagingState<Key, Item> {
        // Reconstruct pages in the shape PagingState expects. For now,
        // expose the whole loaded window as a single synthetic page — the
        // cursors are unknown here (they live in the fetcher).
        PagingState(
            pages: loadedItems.isEmpty
                ? []
                : [LoadedPage(items: loadedItems, previousKey: nil, nextKey: nil)],
            anchorPosition: anchorPosition,
            config: pager.config,
            leadingPlaceholderCount: itemsBefore
        )
    }

    // MARK: Load-state mutators

    private func setSourceLoading(_ kind: Kind) {
        let source = loadState.source ?? .idle
        let newSource = LoadStates(
            refresh: kind == .refresh ? .loading : source.refresh,
            prepend: kind == .prepend ? .loading : source.prepend,
            append: kind == .append ? .loading : source.append
        )
        rebuildCombined(source: newSource, mediator: loadState.mediator)
    }

    private func setSourceNotLoading(refreshEOP: Bool, prependEOP: Bool, appendEOP: Bool) {
        let newSource = LoadStates(
            refresh: .notLoading(endOfPaginationReached: refreshEOP),
            prepend: .notLoading(endOfPaginationReached: prependEOP),
            append: .notLoading(endOfPaginationReached: appendEOP)
        )
        rebuildCombined(source: newSource, mediator: loadState.mediator)
    }

    private func setSourcePrependNotLoading(prependEOP: Bool, appendEOP: Bool?) {
        let source = loadState.source ?? .idle
        let newSource = LoadStates(
            refresh: source.refresh,
            prepend: .notLoading(endOfPaginationReached: prependEOP),
            append: appendEOP.map { .notLoading(endOfPaginationReached: $0) } ?? source.append
        )
        rebuildCombined(source: newSource, mediator: loadState.mediator)
    }

    private func setSourceAppendNotLoading(appendEOP: Bool, prependEOP: Bool?) {
        let source = loadState.source ?? .idle
        let newSource = LoadStates(
            refresh: source.refresh,
            prepend: prependEOP.map { .notLoading(endOfPaginationReached: $0) } ?? source.prepend,
            append: .notLoading(endOfPaginationReached: appendEOP)
        )
        rebuildCombined(source: newSource, mediator: loadState.mediator)
    }

    private func setSourceFailure(_ kind: Kind, error: any Error & Sendable) {
        let source = loadState.source ?? .idle
        let newSource = LoadStates(
            refresh: kind == .refresh ? .failure(error) : source.refresh,
            prepend: kind == .prepend ? .failure(error) : source.prepend,
            append: kind == .append ? .failure(error) : source.append
        )
        rebuildCombined(source: newSource, mediator: loadState.mediator)
    }

    private func setMediatorLoading(_ loadType: LoadType) {
        let mediator = loadState.mediator ?? .idle
        let newMediator = LoadStates(
            refresh: loadType == .refresh ? .loading : mediator.refresh,
            prepend: loadType == .prepend ? .loading : mediator.prepend,
            append: loadType == .append ? .loading : mediator.append
        )
        rebuildCombined(source: loadState.source, mediator: newMediator)
    }

    private func setMediatorNotLoading(_ loadType: LoadType, endOfPaginationReached: Bool) {
        let mediator = loadState.mediator ?? .idle
        let next: LoadState = .notLoading(endOfPaginationReached: endOfPaginationReached)
        let newMediator = LoadStates(
            refresh: loadType == .refresh ? next : mediator.refresh,
            prepend: loadType == .prepend ? next : mediator.prepend,
            append: loadType == .append ? next : mediator.append
        )
        rebuildCombined(source: loadState.source, mediator: newMediator)
    }

    private func setMediatorFailure(_ loadType: LoadType, error: any Error & Sendable) {
        let mediator = loadState.mediator ?? .idle
        let newMediator = LoadStates(
            refresh: loadType == .refresh ? .failure(error) : mediator.refresh,
            prepend: loadType == .prepend ? .failure(error) : mediator.prepend,
            append: loadType == .append ? .failure(error) : mediator.append
        )
        rebuildCombined(source: loadState.source, mediator: newMediator)
    }

    private func rebuildCombined(source: LoadStates?, mediator: LoadStates?) {
        let srcTriple = source ?? .idle
        if let mediator {
            loadState = CombinedLoadStates(
                refresh: CombinedLoadStates.combine(srcTriple.refresh, mediator.refresh),
                prepend: CombinedLoadStates.combine(srcTriple.prepend, mediator.prepend),
                append: CombinedLoadStates.combine(srcTriple.append, mediator.append),
                source: source,
                mediator: mediator
            )
        } else {
            loadState = CombinedLoadStates(
                refresh: srcTriple.refresh,
                prepend: srcTriple.prepend,
                append: srcTriple.append,
                source: source,
                mediator: nil
            )
        }
    }
}
