import Foundation
@testable import LazyPaging

/// Shared test fixture item used across suites.
struct TestItem: Identifiable, Hashable, Sendable {
    let id: Int
    let label: String

    init(id: Int, label: String? = nil) {
        self.id = id
        self.label = label ?? "#\(id)"
    }
}

/// Error stub with an equatable identity so failure tests can assert on it.
struct TestError: Error, Equatable, Sendable {
    let tag: String
}
