import Foundation

/// Bounds how many callers can hold a slot at once; extra callers queue FIFO and are
/// resumed in the order they arrived as slots free up. Used to cap concurrent CPU/memory-
/// heavy work (e.g. image decoding) so a burst — like fast-scrolling through many grid
/// cells at once — can't spike memory or starve the CPU.
///
/// `acquire()` is cancellation-aware: a caller that's no longer interested in the slot
/// (e.g. a SwiftUI cell that scrolled offscreen) is dropped from the queue instead of
/// running its held-up work anyway once its turn eventually comes. Without this, capping
/// concurrency only throttles a burst instead of preventing the backlog it queues up from
/// still being carried out in full.
actor ConcurrencyLimiter {
    private let maxConcurrent: Int
    private(set) var activeCount = 0
    private(set) var waitingCount = 0
    private var waitQueue: [(id: UUID, continuation: CheckedContinuation<Bool, Never>)] = []
    // Cancellations that arrived before the matching waiter was enqueued (the
    // `onCancel` handler can fire immediately, ahead of `operation` below, if the
    // task was already cancelled). Consulted once by that waiter's enqueue step.
    private var preCancelledIDs: Set<UUID> = []

    init(maxConcurrent: Int) {
        self.maxConcurrent = max(1, maxConcurrent)
    }

    /// Returns `false` without granting a slot if the caller is cancelled, either
    /// already or while queued, so cancelled callers neither occupy a slot nor
    /// wait through the full queue just to have their result thrown away.
    @discardableResult
    func acquire() async -> Bool {
        if Task.isCancelled { return false }
        if activeCount < maxConcurrent {
            activeCount += 1
            return true
        }
        waitingCount += 1
        let id = UUID()
        let granted = await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                if preCancelledIDs.remove(id) != nil {
                    continuation.resume(returning: false)
                } else {
                    waitQueue.append((id, continuation))
                }
            }
        } onCancel: { [weak self] in
            Task { await self?.cancelWaiter(id) }
        }
        waitingCount -= 1
        return granted
    }

    func release() {
        activeCount -= 1
        guard !waitQueue.isEmpty else { return }
        let next = waitQueue.removeFirst()
        activeCount += 1
        next.continuation.resume(returning: true)
    }

    /// Removes a queued waiter and resumes it as not granted. If cancellation raced
    /// ahead of the waiter being enqueued, remembers it so the enqueue step above
    /// resolves immediately instead of waiting in line for nothing.
    ///
    /// Note: if `release()` happens to grant this exact waiter its slot in the same
    /// instant it's being cancelled, this falls into the "not found" branch below and
    /// stores an entry in `preCancelledIDs` that nothing will ever consume — a single
    /// stray UUID per occurrence of that narrow race. Harmless and not worth the extra
    /// bookkeeping it'd take to close entirely.
    private func cancelWaiter(_ id: UUID) {
        guard let index = waitQueue.firstIndex(where: { $0.id == id }) else {
            preCancelledIDs.insert(id)
            return
        }
        let removed = waitQueue.remove(at: index)
        removed.continuation.resume(returning: false)
    }
}
