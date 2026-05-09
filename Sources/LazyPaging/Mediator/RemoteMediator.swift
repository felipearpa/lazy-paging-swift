import Foundation

/// Coordinates network loads with a local ``PagingSource`` that reads
/// from an on-device store. Mirrors AndroidX Paging's `RemoteMediator`.
///
/// Typical shape:
///
/// 1. ``initialize()`` returns whether a mediator refresh should run on
///    first launch (defaults to ``InitializeAction/launchInitialRefresh``).
/// 2. On **refresh**, the pager calls ``load(loadType:state:)`` with
///    ``LoadType/refresh`` before the local source reads, so the
///    mediator can populate the store.
/// 3. On **append** / **prepend**, the mediator is invoked only when the
///    local source returns end-of-pagination in that direction — i.e. the
///    store is exhausted. After a successful mediator load, the local
///    source is invalidated so the UI picks up the newly written data.
///
/// The mediator is responsible for writing to the store; the local
/// ``PagingSource`` is responsible for reading from it. This package stays
/// storage-agnostic (SwiftData, Core Data, an in-memory array, …) — wire
/// the mediator and source to the same store.
public protocol RemoteMediator<Key, Item>: Sendable {
    associatedtype Key: Hashable & Sendable
    associatedtype Item: Sendable

    func initialize() async -> InitializeAction
    func load(loadType: LoadType, state: PagingState<Key, Item>) async -> MediatorResult
}

public extension RemoteMediator {
    func initialize() async -> InitializeAction { .launchInitialRefresh }
}
