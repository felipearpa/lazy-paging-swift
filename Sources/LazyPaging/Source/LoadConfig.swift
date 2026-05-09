import Foundation

/// Parameters handed to a ``PagingSource`` for a single load operation.
///
/// Mirrors AndroidX Paging's `LoadParams`: carries the key, the kind of load
/// (refresh/prepend/append), and the number of items the pager would like.
/// The source is free to return more or fewer — `loadSize` is advisory.
public struct LoadConfig<Key: Sendable>: Sendable {
    public enum Kind: Sendable {
        case refresh
        case prepend
        case append
    }

    public let key: Key?
    public let kind: Kind
    public let loadSize: Int

    public init(key: Key?, kind: Kind, loadSize: Int) {
        self.key = key
        self.kind = kind
        self.loadSize = loadSize
    }
}
