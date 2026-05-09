import Foundation

typealias InvalidateAction = @Sendable () async -> Void

/// Thread-safe registry of callbacks fired when a ``PagingSource`` is invalidated.
actor InvalidateActionTracker {
    private var actions: [UUID: InvalidateAction] = [:]

    func register(_ action: @escaping InvalidateAction) -> UUID {
        let id = UUID()
        actions[id] = action
        return id
    }

    func unregister(id: UUID) {
        actions.removeValue(forKey: id)
    }

    func invalidate() async {
        let snapshot = actions.values
        for action in snapshot {
            await action()
        }
    }
}
