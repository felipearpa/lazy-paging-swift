import Foundation

/// Represents the state of a single load operation (refresh, prepend, or append).
///
/// Aligned with AndroidX Paging's `LoadState`:
///
/// - ``notLoading(endOfPaginationReached:)`` — idle. `endOfPaginationReached`
///   tells the UI whether more pages may still come from this direction.
/// - ``loading`` — a load is in flight.
/// - ``failure(_:)`` — the last load failed.
public enum LoadState: Sendable {
    case notLoading(endOfPaginationReached: Bool)
    case loading
    case failure(any Error & Sendable)
}

public extension LoadState {
    var endOfPaginationReached: Bool {
        if case .notLoading(let reached) = self { return reached }
        return false
    }

    var isNotLoading: Bool {
        if case .notLoading = self { return true }
        return false
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }

    var error: (any Error)? {
        if case .failure(let error) = self { return error }
        return nil
    }
}

extension LoadState: Equatable {
    public static func == (lhs: LoadState, rhs: LoadState) -> Bool {
        switch (lhs, rhs) {
        case (.notLoading(let l), .notLoading(let r)):
            return l == r
        case (.loading, .loading):
            return true
        case (.failure(let lError), .failure(let rError)):
            return type(of: lError) == type(of: rError)
        default:
            return false
        }
    }
}
