import SwiftUI
import LazyPaging

/// Top-level showcase screen that mirrors the KMP sample: pick a scenario,
/// watch ``RefreshableLazyPagingVStack`` exercise loading / empty / error /
/// content states and render placeholder rows for unloaded positions.
public struct ShowcaseScreen: View {
    @State private var scenario: Scenario = .bidirectional

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                ScenarioPicker(selected: $scenario)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                Text(scenario.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)

                // `.id(scenario)` rebuilds `ScenarioContent` (and re-runs its
                // `@StateObject` initialiser) when the user picks a new
                // scenario. `@StateObject` doesn't allow reassignment, so the
                // recreate-by-id pattern is what gives us a fresh
                // `LazyPagingItems` per scenario.
                ScenarioContent(scenario: scenario)
                    .id(scenario)
            }
            .navigationTitle("lazy-paging showcase")
        }
    }
}

private struct ScenarioContent: View {
    let scenario: Scenario
    @StateObject private var lazyPagingItems: LazyPagingItems<Int, SampleItem>

    init(scenario: Scenario) {
        self.scenario = scenario
        _lazyPagingItems = StateObject(
            wrappedValue: LazyPagingItems(pager: scenario.pager())
        )
    }

    var body: some View {
        if scenario.usesStickyHeaders {
            StickyHeadersScreen(lazyPagingItems: lazyPagingItems)
        } else {
            RefreshableLazyPagingVStack(
                lazyPagingItems: lazyPagingItems,
                spacing: 8,
                contentInsets: EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16),
                loadingContent: { LoadingView() },
                emptyContent: { EmptyStateView() },
                errorContent: { error in
                    ErrorStateView(error: error) {
                        Task { await lazyPagingItems.retry() }
                    }
                },
                prependLoadingContent: { LoadingFooter(text: "Loading previous…") },
                appendLoadingContent: { LoadingFooter(text: "Loading more…") },
                prependErrorContent: { error in
                    RetryFooter(message: "Failed to load previous page", error: error) {
                        Task { await lazyPagingItems.retry() }
                    }
                },
                appendErrorContent: { error in
                    RetryFooter(message: "Failed to load next page", error: error) {
                        Task { await lazyPagingItems.retry() }
                    }
                },
                rowContent: { index in
                    rowContent(at: index)
                }
            )
        }
    }

    @ViewBuilder
    private func rowContent(at index: Int) -> some View {
        if let item = lazyPagingItems[index] {
            ItemRow(item: item)
        } else if index < lazyPagingItems.itemsBefore {
            leadingPlaceholder(at: index)
        } else {
            trailingPlaceholder(at: index)
        }
    }

    @ViewBuilder
    private func leadingPlaceholder(at index: Int) -> some View {
        let firstLoaded = lazyPagingItems.itemsBefore
        let isBoundary = index == firstLoaded - 1
        if case .failure(let error) = lazyPagingItems.loadState.prepend {
            if isBoundary {
                BoundaryErrorRow(message: "Prepend failed", error: error) {
                    Task { await lazyPagingItems.retry() }
                }
            } else {
                EmptyView()
            }
        } else {
            PlaceholderRow(label: "Loading previous...")
        }
    }

    @ViewBuilder
    private func trailingPlaceholder(at index: Int) -> some View {
        let firstTrailing = lazyPagingItems.itemsBefore + lazyPagingItems.loadedItems.count
        let isBoundary = index == firstTrailing
        if case .failure(let error) = lazyPagingItems.loadState.append {
            if isBoundary {
                BoundaryErrorRow(message: "Append failed", error: error) {
                    Task { await lazyPagingItems.retry() }
                }
            } else {
                EmptyView()
            }
        } else {
            PlaceholderRow(label: "Loading more...")
        }
    }
}

private struct ScenarioPicker: View {
    @Binding var selected: Scenario

    var body: some View {
        Menu {
            ForEach(Scenario.allCases) { option in
                Button {
                    selected = option
                } label: {
                    if option == selected {
                        Label(option.displayName, systemImage: "checkmark")
                    } else {
                        Text(option.displayName)
                    }
                }
            }
        } label: {
            HStack {
                Text("Scenario: \(selected.displayName)")
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.secondary.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ItemRow: View {
    let item: SampleItem

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.tint.opacity(0.2))
                Text("\(item.id)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
            }
            .frame(width: 36, height: 36)

            Text(item.label)
                .font(.body)

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        )
    }
}

private struct LoadingView: View {
    var body: some View {
        VStack {
            Spacer(minLength: 120)
            ProgressView()
                .controlSize(.large)
            Spacer(minLength: 120)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack {
            Spacer(minLength: 120)
            Text("Nothing to show yet.")
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer(minLength: 120)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ErrorStateView: View {
    let error: any Error
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 80)
            Text("Something went wrong")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            Button("Retry", action: onRetry)
                .buttonStyle(.borderedProminent)
            Spacer(minLength: 80)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct BoundaryErrorRow: View {
    let message: String
    let error: any Error
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Retry", action: onRetry)
                .buttonStyle(.bordered)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        )
    }
}

private struct LoadingFooter: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
    }
}

private struct RetryFooter: View {
    let message: String
    let error: any Error
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Retry", action: onRetry)
                .buttonStyle(.bordered)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        )
    }
}

private struct PlaceholderRow: View {
    let label: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .shadow(color: .black.opacity(0.03), radius: 1, y: 1)
        )
    }
}
