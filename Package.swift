// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "lazy-paging-swift",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "LazyPaging",
            targets: ["LazyPaging"]
        ),
        .library(
            name: "LazyPagingShowcase",
            targets: ["LazyPagingShowcase"]
        ),
        .executable(
            name: "LazyPagingShowcaseApp",
            targets: ["LazyPagingShowcaseApp"]
        ),
    ],
    targets: [
        .target(
            name: "LazyPaging",
            path: "Sources/LazyPaging"
        ),
        .target(
            name: "LazyPagingShowcase",
            dependencies: ["LazyPaging"],
            path: "Sources/LazyPagingShowcase"
        ),
        .executableTarget(
            name: "LazyPagingShowcaseApp",
            dependencies: ["LazyPagingShowcase"],
            path: "Sources/LazyPagingShowcaseApp"
        ),
        .testTarget(
            name: "LazyPagingTests",
            dependencies: ["LazyPaging"],
            path: "Tests/LazyPagingTests"
        ),
    ]
)
