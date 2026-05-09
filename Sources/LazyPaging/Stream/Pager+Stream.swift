import Foundation

public extension Pager {
    /// One-shot snapshot: creates a fresh ``PagingSource`` and returns the
    /// ``PagingData`` that wraps it. Use this when you want a single paging
    /// session; use ``stream`` when you want re-emission on invalidation.
    func pagingData() -> PagingData<Key, Item> {
        PagingData(pager: self, source: pagingSourceFactory())
    }

    /// Cold `AsyncStream` that yields a fresh ``PagingData`` when the
    /// consumer subscribes, and a new one every time the current
    /// ``PagingSource`` is invalidated. Mirrors AndroidX `Pager.flow`.
    ///
    /// Backed by a single cooperating task; cancellation propagates through
    /// the stream's `onTermination` hook so no tasks leak when the consumer
    /// stops iterating.
    var stream: AsyncStream<PagingData<Key, Item>> {
        let pagerCopy = self

        return AsyncStream<PagingData<Key, Item>> { streamContinuation in
            let task = Task {
                while !Task.isCancelled {
                    let source = pagerCopy.pagingSourceFactory()

                    // Set up an AsyncStream signal that fires when this
                    // source is invalidated. We register the callback
                    // before we yield so the consumer can't miss it.
                    let (invalidations, invalidationContinuation) = AsyncStream<Void>.makeStream()
                    let invalidateId = await source.registerInvalidateAction {
                        invalidationContinuation.yield()
                    }

                    streamContinuation.yield(PagingData(pager: pagerCopy, source: source))

                    // Wait for the first invalidation (or task cancellation).
                    for await _ in invalidations {
                        break
                    }

                    invalidationContinuation.finish()
                    await source.unregisterInvalidateAction(id: invalidateId)
                }
                streamContinuation.finish()
            }

            streamContinuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
