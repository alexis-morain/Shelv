import Foundation

/// Bounds how many callers can hold a slot at once; extra callers queue FIFO and are
/// resumed in the order they arrived as slots free up. Used to cap concurrent CPU/memory-
/// heavy work (e.g. image decoding) so a burst — like fast-scrolling through many grid
/// cells at once — can't spike memory or starve the CPU.
actor ConcurrencyLimiter {
    private let maxConcurrent: Int
    private(set) var activeCount = 0
    private(set) var waitingCount = 0
    private var waitQueue: [CheckedContinuation<Void, Never>] = []

    init(maxConcurrent: Int) {
        self.maxConcurrent = max(1, maxConcurrent)
    }

    func acquire() async {
        if activeCount < maxConcurrent {
            activeCount += 1
            return
        }
        waitingCount += 1
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            waitQueue.append(continuation)
        }
        waitingCount -= 1
        activeCount += 1
    }

    func release() {
        activeCount -= 1
        if !waitQueue.isEmpty {
            waitQueue.removeFirst().resume()
        }
    }
}
