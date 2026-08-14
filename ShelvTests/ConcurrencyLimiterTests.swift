import XCTest

private actor PeakRecorder {
    private(set) var peak = 0
    func record(_ value: Int) {
        peak = max(peak, value)
    }
}

final class ConcurrencyLimiterTests: XCTestCase {
    func testAcquireUpToTheLimitDoesNotBlock() async {
        let limiter = ConcurrencyLimiter(maxConcurrent: 3)
        await limiter.acquire()
        await limiter.acquire()
        await limiter.acquire()

        let active = await limiter.activeCount
        let waiting = await limiter.waitingCount
        XCTAssertEqual(active, 3)
        XCTAssertEqual(waiting, 0)
    }

    func testExtraAcquireQueuesUntilASlotIsReleased() async {
        let limiter = ConcurrencyLimiter(maxConcurrent: 1)
        await limiter.acquire()

        let second = Task { await limiter.acquire() }

        // Deterministic wait: yield until the second caller has registered as
        // queued, rather than a fixed sleep — avoids both flakiness and a hang
        // (bounded by the iteration count, which only trips if acquire() is
        // actually broken and never queues the caller).
        for _ in 0..<1000 {
            if await limiter.waitingCount == 1 { break }
            await Task.yield()
        }
        let activeBeforeRelease = await limiter.activeCount
        let waitingBeforeRelease = await limiter.waitingCount
        XCTAssertEqual(activeBeforeRelease, 1)
        XCTAssertEqual(waitingBeforeRelease, 1)

        await limiter.release()
        await second.value

        let activeAfter = await limiter.activeCount
        let waitingAfter = await limiter.waitingCount
        XCTAssertEqual(activeAfter, 1)
        XCTAssertEqual(waitingAfter, 0)
    }

    func testConcurrencyNeverExceedsTheLimitAcrossABurstOfTasks() async {
        let limiter = ConcurrencyLimiter(maxConcurrent: 3)
        let recorder = PeakRecorder()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<50 {
                group.addTask {
                    await limiter.acquire()
                    await recorder.record(await limiter.activeCount)
                    try? await Task.sleep(for: .milliseconds(1))
                    await limiter.release()
                }
            }
        }

        let peak = await recorder.peak
        XCTAssertLessThanOrEqual(peak, 3)

        let activeAfter = await limiter.activeCount
        let waitingAfter = await limiter.waitingCount
        XCTAssertEqual(activeAfter, 0)
        XCTAssertEqual(waitingAfter, 0)
    }

    func testAcquireReturnsFalseWhenAlreadyCancelled() async {
        let limiter = ConcurrencyLimiter(maxConcurrent: 3)
        // The sleep guarantees cancel() below lands before the task body reaches
        // acquire() — without it, the task could race ahead and acquire a slot
        // before the immediately-following cancel() call takes effect.
        let task = Task<Bool, Never> {
            try? await Task.sleep(for: .milliseconds(10))
            return await limiter.acquire()
        }
        task.cancel()

        let granted = await task.value
        XCTAssertFalse(granted)
        let active = await limiter.activeCount
        XCTAssertEqual(active, 0)
    }

    /// The scenario this exists for: a SwiftUI cell scrolls offscreen (its `.task` is
    /// cancelled) while its image decode is still queued behind the concurrency cap. It
    /// must drop out of the queue instead of eventually running the decode for nothing.
    func testCancellingAQueuedAcquireResumesWithoutGrantingASlot() async {
        let limiter = ConcurrencyLimiter(maxConcurrent: 1)
        await limiter.acquire() // occupies the only slot

        let waiter = Task { await limiter.acquire() }
        for _ in 0..<1000 {
            if await limiter.waitingCount == 1 { break }
            await Task.yield()
        }
        waiter.cancel()

        let granted = await waiter.value
        XCTAssertFalse(granted)
        let waitingAfter = await limiter.waitingCount
        let activeAfter = await limiter.activeCount
        XCTAssertEqual(waitingAfter, 0)
        XCTAssertEqual(activeAfter, 1, "the original holder's slot must be untouched")

        await limiter.release()
        let activeFinal = await limiter.activeCount
        XCTAssertEqual(activeFinal, 0)
    }

    func testCancellingOneQueuedWaiterStillGrantsTheOthersInOrder() async {
        let limiter = ConcurrencyLimiter(maxConcurrent: 1)
        await limiter.acquire()

        // Queued one at a time (each awaited into place) so the FIFO order is
        // deterministic — creating all three concurrently wouldn't guarantee
        // which reaches the queue first.
        let first = Task { await limiter.acquire() }
        for _ in 0..<1000 {
            if await limiter.waitingCount == 1 { break }
            await Task.yield()
        }
        let toCancel = Task { await limiter.acquire() }
        for _ in 0..<1000 {
            if await limiter.waitingCount == 2 { break }
            await Task.yield()
        }
        let second = Task { await limiter.acquire() }
        for _ in 0..<1000 {
            if await limiter.waitingCount == 3 { break }
            await Task.yield()
        }

        toCancel.cancel()
        let cancelledGranted = await toCancel.value
        XCTAssertFalse(cancelledGranted)

        await limiter.release()
        let firstGranted = await first.value
        XCTAssertTrue(firstGranted)

        await limiter.release()
        let secondGranted = await second.value
        XCTAssertTrue(secondGranted)

        let activeAfter = await limiter.activeCount
        let waitingAfter = await limiter.waitingCount
        XCTAssertEqual(activeAfter, 1)
        XCTAssertEqual(waitingAfter, 0)

        await limiter.release()
    }
}
