import Foundation

/// Outcome of a ``RemoteMediator/load(loadType:state:)`` call.
///
/// - `success(endOfPaginationReached:)` — the mediator wrote new data to
///   its backing store (or confirmed none was available). When
///   `endOfPaginationReached` is `true`, the pager will stop calling the
///   mediator in that direction.
/// - `failure(_:)` — the mediator failed; the error is surfaced through
///   ``CombinedLoadStates/mediator``.
public enum MediatorResult: Sendable {
    case success(endOfPaginationReached: Bool)
    case failure(any Error & Sendable)
}
