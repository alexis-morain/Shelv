import XCTest

final class AudioPlayerStreamCacheWindowPlanTests: XCTestCase {
    func testOfflineWindowKeepsDesiredSongsWhenNoJobsCanBeScheduled() {
        let plan = AudioPlayerStreamCacheWindowPlan(
            currentSongId: "current",
            desiredUpcomingSongIds: ["next-1", "next-2", "next-3", "next-4", "next-5"],
            schedulableJobSongIds: []
        )

        XCTAssertEqual(
            plan.keepSongIds,
            ["current", "next-1", "next-2", "next-3", "next-4", "next-5"]
        )
        XCTAssertEqual(plan.schedulingSignature, ["current"])
    }

    func testOnlineWindowSchedulesDesiredSongsAndKeepsTheSameFiles() {
        let upcoming = ["next-1", "next-2", "next-3", "next-4", "next-5"]
        let plan = AudioPlayerStreamCacheWindowPlan(
            currentSongId: "current",
            desiredUpcomingSongIds: upcoming,
            schedulableJobSongIds: upcoming
        )

        XCTAssertEqual(plan.keepSongIds, Set(upcoming).union(["current"]))
        XCTAssertEqual(plan.schedulingSignature, ["current"] + upcoming)
    }

    func testRecentlyPlayedSongsAreKeptButNeverScheduled() {
        let plan = AudioPlayerStreamCacheWindowPlan(
            currentSongId: "current",
            desiredUpcomingSongIds: ["next-1"],
            desiredBehindSongIds: ["previous-1", "previous-2"],
            schedulableJobSongIds: ["next-1"]
        )

        XCTAssertEqual(plan.keepSongIds, ["current", "next-1", "previous-1", "previous-2"])
        XCTAssertEqual(plan.schedulingSignature, ["current", "next-1"])
    }

    func testOverlappingBehindAndUpcomingSongIdsDoNotDuplicate() {
        let plan = AudioPlayerStreamCacheWindowPlan(
            currentSongId: "current",
            desiredUpcomingSongIds: ["shared"],
            desiredBehindSongIds: ["shared"],
            schedulableJobSongIds: []
        )

        XCTAssertEqual(plan.keepSongIds, ["current", "shared"])
    }
}
