import Foundation

/// Result produced by a ``PagingSource`` load.
///
/// - ``page(items:previousKey:nextKey:itemsBefore:itemsAfter:)`` carries the
///   newly fetched items and the optional keys used to request the pages
///   before and after this one. A `nil` key means that end of the list has
///   been reached. `itemsBefore` / `itemsAfter` let the source report the
///   number of not-yet-loaded items so the UI can render placeholder rows
///   (AndroidX Paging's placeholder model).
/// - ``failure(_:)`` — the source failed; the error is surfaced through
///   ``LoadState/failure(_:)``.
/// - ``invalid`` — the source was invalidated during this load and the
///   in-flight result must be discarded. ``LazyPagingItems`` reacts by
///   dropping the result and triggering a fresh refresh.
public enum LoadResult<Key: Sendable, Item: Sendable>: Sendable {
    case page(
        items: [Item],
        previousKey: Key?,
        nextKey: Key?,
        itemsBefore: Int = 0,
        itemsAfter: Int = 0
    )
    case failure(any Error & Sendable)
    case invalid
}
