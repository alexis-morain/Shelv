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
}
