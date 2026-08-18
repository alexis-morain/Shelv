import XCTest

final class InfinityMixPoolBuilderTests: XCTestCase {
    func testPoolKeepsSimilarSongsFirstAndMixesInDiscovery() {
        let pool = InfinityMixPoolBuilder.pool(
            similar: (1...8).map { song("similar-\($0)") },
            discovery: (1...8).map { song("random-\($0)") },
            limit: 8
        )

        XCTAssertEqual(
            pool.map(\.id),
            [
                "similar-1", "similar-2", "similar-3", "random-1",
                "similar-4", "similar-5", "similar-6", "random-2"
            ]
        )
    }

    func testPoolSkipsExcludedAndDuplicateSongs() {
        let pool = InfinityMixPoolBuilder.pool(
            similar: [song("a"), song("recent"), song("a"), song("b")],
            discovery: [song("b"), song("c")],
            excluding: ["recent"],
            limit: 8
        )

        XCTAssertEqual(pool.map(\.id), ["a", "b", "c"])
    }

    func testPoolFallsBackToDiscoveryWhenNoSimilarSongsAreLeft() {
        let pool = InfinityMixPoolBuilder.pool(
            similar: [song("only-similar")],
            discovery: [song("random-1"), song("random-2")],
            limit: 3
        )

        XCTAssertEqual(pool.map(\.id), ["only-similar", "random-1", "random-2"])
    }

    func testShortSimilarListStillFillsThePoolFromDiscovery() {
        let pool = InfinityMixPoolBuilder.pool(
            similar: (1...8).map { song("similar-\($0)") },
            discovery: (1...40).map { song("random-\($0)") },
            limit: InfinityMixPoolBuilder.poolSize
        )

        XCTAssertEqual(pool.count, InfinityMixPoolBuilder.poolSize)
        XCTAssertEqual(pool.filter { $0.id.hasPrefix("similar-") }.count, 8)
        XCTAssertEqual(Set(pool.map(\.id)).count, pool.count)
    }

    func testPoolStopsWhenBothSourcesAreExhausted() {
        let pool = InfinityMixPoolBuilder.pool(
            similar: [song("a")],
            discovery: [],
            limit: 25
        )

        XCTAssertEqual(pool.map(\.id), ["a"])
    }

    func testPoolIsEmptyForNonPositiveLimit() {
        XCTAssertTrue(
            InfinityMixPoolBuilder.pool(similar: [song("a")], discovery: [song("b")], limit: 0).isEmpty
        )
    }

    func testHistoryKeepsMostRecentIdsWithoutDuplicates() {
        let history = InfinityMixPoolBuilder.appendingHistory(["a", "b", "c"], adding: ["d", "b"], limit: 3)

        XCTAssertEqual(history, ["c", "d", "b"])
    }

    func testHistoryGrowsUntilTheLimitIsReached() {
        let history = InfinityMixPoolBuilder.appendingHistory([], adding: ["a", "b"], limit: 5)

        XCTAssertEqual(history, ["a", "b"])
    }

    private func song(_ id: String) -> Song {
        Song(id: id, title: id)
    }
}
