import Foundation

/// Top-level entry point for paging. Mirrors AndroidX's `Pager`: bundles a
/// ``PagingConfig``, a factory that produces a fresh ``PagingSource`` for
/// each new stream, an optional ``RemoteMediator`` that coordinates
/// network-to-local-store writes, and the optional initial key used by
/// the first refresh.
public struct Pager<Key: Hashable & Sendable, Item: Sendable>: Sendable {
    public let config: PagingConfig
    public let pagingSourceFactory: @Sendable () -> PagingSource<Key, Item>
    public let initialKey: Key?
    public let remoteMediator: (any RemoteMediator<Key, Item>)?

    public init(
        config: PagingConfig,
        remoteMediator: (any RemoteMediator<Key, Item>)? = nil,
        pagingSourceFactory: @escaping @Sendable () -> PagingSource<Key, Item>,
        initialKey: Key? = nil
    ) {
        self.config = config
        self.remoteMediator = remoteMediator
        self.pagingSourceFactory = pagingSourceFactory
        self.initialKey = initialKey
    }
}
