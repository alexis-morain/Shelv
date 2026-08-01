import XCTest

final class RecapSyncLogicTests: XCTestCase {
    func testPlaylistMutationReplacesMissingExtraAndMisorderedSongsAtOnce() throws {
        let current = ["extra", "most-played", "existing"]
        let expected = ["most-played", "missing", "existing"]

        let plan = try XCTUnwrap(
            RecapPlaylistMutationPlan(currentIds: current, expectedIds: expected)
        )

        XCTAssertEqual(plan.songIdsToAdd, expected)
        XCTAssertEqual(plan.songIndicesToRemove, [0, 1, 2])
        XCTAssertNil(RecapPlaylistMutationPlan(currentIds: expected, expectedIds: expected))
    }

    func testPlaylistVerificationRequiresExactContentOrderNameAndComment() {
        let expected = ["first", "second", "third"]

        XCTAssertTrue(RecapSyncLogic.playlistMatches(
            ids: expected,
            name: "June 2026",
            comment: "Shelv Recap",
            expectedIds: expected,
            expectedName: "June 2026"
        ))
        XCTAssertFalse(RecapSyncLogic.playlistMatches(
            ids: ["second", "first", "third"],
            name: "June 2026",
            comment: "Shelv Recap",
            expectedIds: expected,
            expectedName: "June 2026"
        ))
        XCTAssertFalse(RecapSyncLogic.playlistMatches(
            ids: expected,
            name: "Wrong name",
            comment: "Shelv Recap",
            expectedIds: expected,
            expectedName: "June 2026"
        ))
        XCTAssertFalse(RecapSyncLogic.playlistMatches(
            ids: expected,
            name: "June 2026",
            comment: nil,
            expectedIds: expected,
            expectedName: "June 2026"
        ))
    }

    func testNotFoundClassificationOnlyAcceptsDefinitiveServerResponses() {
        XCTAssertTrue(RecapSyncLogic.isDefinitiveNotFound(code: 70, message: nil))
        XCTAssertTrue(RecapSyncLogic.isDefinitiveNotFound(code: 0, message: "Song not found"))
        XCTAssertFalse(RecapSyncLogic.isDefinitiveNotFound(code: 0, message: "Temporary failure"))
        XCTAssertFalse(RecapSyncLogic.isDefinitiveNotFound(code: 40, message: "Wrong credentials"))
    }

    func testDeletionQueueOnlyCompletesDeletedOrAlreadyMissingRecords() {
        let dispositions: [String: PendingDeletionDisposition] = [
            "deleted": .completed,
            "already-missing": .completed,
            "network-failure": .retry,
            "missing-result": .retry
        ]

        XCTAssertEqual(
            RecapSyncLogic.completedDeletionIDs(from: dispositions),
            Set(["deleted", "already-missing"])
        )
    }
}
