import SwiftUI
import LazyPaging

/// Sticky-headers showcase view. Demonstrates that real sticky group headers
/// require composing directly against ``LazyPagingItems`` rather than going
/// through ``LazyPagingVStack``: each group becomes one ``Section`` so its
/// header stays pinned while any row of the group is on screen.
///
/// The grouping bucket is `item.id / 10`, so every 10 items share a header.
/// Placeholder slots (before/after the loaded window) lump into synthetic
/// "pending" sections — one per contiguous run.
struct StickyHeadersScreen: View {
    @ObservedObject var lazyPagingItems: LazyPagingItems<Int, SampleItem>

    // Drives the initial-key scroll jump after refresh — see the matching
    // comment in `LazyPagingVStack` for why we go through `.onChange` rather
    // than calling `proxy.scrollTo` synchronously inside `.task`.
    @State private var initialScrollTarget: Int?

    var body: some View {
        let columnState = resolveLazyPagingVStackState(
            refresh: lazyPagingItems.loadState.refresh,
            prepend: lazyPagingItems.loadState.prepend,
            append: lazyPagingItems.loadState.append,
            itemCount: lazyPagingItems.itemCount,
            current: lazyPagingItems.itemCount > 0 ? .content : .loading
        )

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8, pinnedViews: .sectionHeaders) {
                    switch columnState {
                    case .loading:
                        LoadingPlaceholder()
                    case .empty:
                        EmptyPlaceholder()
                    case .error(let error):
                        ErrorPlaceholder(error: error) {
                            Task { await lazyPagingItems.retry() }
                        }
                    case .content:
                        contentSections
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .task(id: ObjectIdentifier(lazyPagingItems)) {
                initialScrollTarget = nil
                await lazyPagingItems.refresh()
                // Match LazyPagingVStack: when refresh lands in the middle of the
                // dataset (itemsBefore > 0), jump the viewport onto the first
                // loaded row so the user doesn't start inside the leading
                // placeholder band.
                if lazyPagingItems.itemsBefore > 0 {
                    initialScrollTarget = lazyPagingItems.itemsBefore
                }
            }
            .onChange(of: initialScrollTarget) { target in
                guard let target else { return }
                proxy.scrollTo(target, anchor: .top)
            }
            .refreshable { await lazyPagingItems.refresh() }
        }
    }

    @ViewBuilder
    private var contentSections: some View {
        ForEach(groups) { group in
            Section {
                ForEach(group.indices, id: \.self) { index in
                    rowView(at: index)
                        .id(index)
                        .task { await lazyPagingItems.onRowAccess(index: index) }
                }
            } header: {
                GroupHeader(title: group.title)
            }
        }
    }

    @ViewBuilder
    private func rowView(at index: Int) -> some View {
        if let item = lazyPagingItems.peek(at: index) {
            StickyItemRow(item: item)
        } else {
            StickyPlaceholderRow()
        }
    }

    /// Walks `0..<itemCount` and packs consecutive indices that share a
    /// section key into one ``IndexedGroup``. Placeholders (peek == nil) get a
    /// synthetic "pending" key, so each run of unloaded slots forms its own
    /// section — the leading and trailing placeholder bands stay separate
    /// even though they share a key.
    private var groups: [IndexedGroup] {
        var result: [IndexedGroup] = []
        for index in 0..<lazyPagingItems.itemCount {
            let key: GroupKey
            if let item = lazyPagingItems.peek(at: index) {
                key = .loaded(item.id / 10)
            } else {
                key = .pending
            }
            if let last = result.last, last.key == key {
                result[result.count - 1].indices.append(index)
            } else {
                result.append(IndexedGroup(key: key, indices: [index], serial: result.count))
            }
        }
        return result
    }
}

private enum GroupKey: Hashable {
    case loaded(Int)
    case pending
}

private struct IndexedGroup: Identifiable {
    let key: GroupKey
    var indices: [Int]
    let serial: Int

    var id: Int { serial }

    var title: String {
        switch key {
        case .loaded(let bucket):
            let start = bucket * 10
            return "Items \(start)–\(start + 9)"
        case .pending:
            return "Loading…"
        }
    }
}

private struct GroupHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.tint)
    }
}

private struct StickyItemRow: View {
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

private struct StickyPlaceholderRow: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView().controlSize(.small)
            Text("Loading…")
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

private struct LoadingPlaceholder: View {
    var body: some View {
        VStack {
            Spacer(minLength: 120)
            ProgressView().controlSize(.large)
            Spacer(minLength: 120)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct EmptyPlaceholder: View {
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

private struct ErrorPlaceholder: View {
    let error: any Error
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 80)
            Text("Something went wrong").font(.headline)
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
