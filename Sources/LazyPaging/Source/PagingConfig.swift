import Foundation

/// Static configuration for a ``Pager``. Mirrors the relevant fields of
/// AndroidX Paging's `PagingConfig`.
public struct PagingConfig: Sendable, Equatable {
    /// Number of items to load per page. Surfaced to the source through
    /// ``LoadConfig/loadSize``; the source is still free to return any count.
    public let pageSize: Int

    /// Number of items to load on the first refresh. Defaults to `pageSize`
    /// if not specified at init time.
    public let initialLoadSize: Int

    /// Number of items before the edge at which the next page should be
    /// prefetched. Higher values reduce visible loading footers at the cost
    /// of eager fetches.
    public let prefetchDistance: Int

    /// Maximum number of items that may be held in memory. When a successful
    /// append/prepend would push the loaded item count past this limit,
    /// pages are dropped from the opposite end; the dropped range reappears
    /// as placeholder slots and can be re-fetched on scroll back.
    ///
    /// `nil` disables dropping (the default). When set, must be at least
    /// `pageSize * 2 + prefetchDistance` to avoid thrashing — assertion
    /// catches this at construction time.
    public let maxSize: Int?

    public init(
        pageSize: Int,
        initialLoadSize: Int? = nil,
        prefetchDistance: Int? = nil,
        maxSize: Int? = nil
    ) {
        precondition(pageSize > 0, "pageSize must be positive")
        self.pageSize = pageSize
        self.initialLoadSize = initialLoadSize ?? pageSize
        self.prefetchDistance = prefetchDistance ?? pageSize
        self.maxSize = maxSize
        precondition(self.initialLoadSize > 0, "initialLoadSize must be positive")
        precondition(self.prefetchDistance >= 0, "prefetchDistance must be non-negative")
        if let maxSize {
            precondition(
                maxSize >= pageSize * 2 + self.prefetchDistance,
                "maxSize must be at least pageSize * 2 + prefetchDistance to avoid thrashing"
            )
        }
    }
}
