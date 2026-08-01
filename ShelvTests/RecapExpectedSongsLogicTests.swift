import XCTest

final class RecapExpectedSongsLogicTests: XCTestCase {
    func testAllAliveCandidatesPassThroughUnchanged() async throws {
        let resolution = try await RecapExpectedSongsLogic.resolveExpectedIds(
            initial: ["a", "b", "c"],
            backups: ["d", "e"],
            alreadyKnownAlive: { _ in false },
            resolve: { id in id } // alles lebt
        )

        XCTAssertEqual(resolution.finalIds, ["a", "b", "c"])
        XCTAssertEqual(resolution.resolvedItems, ["a": "a", "b": "b", "c": "c"])
    }

    func testSingleDeadCandidateIsReplacedByNextBackupInPlace() async throws {
        let dead: Set<String> = ["b"]
        let resolution = try await RecapExpectedSongsLogic.resolveExpectedIds(
            initial: ["a", "b", "c"],
            backups: ["d", "e"],
            alreadyKnownAlive: { _ in false },
            resolve: { id in dead.contains(id) ? nil : id }
        )

        XCTAssertEqual(resolution.finalIds, ["a", "d", "c"])
        XCTAssertNil(resolution.resolvedItems["b"])
        XCTAssertEqual(resolution.resolvedItems["d"], "d")
    }

    func testConsecutiveDeadBackupsAreSkippedUntilAnAliveOneIsFound() async throws {
        let dead: Set<String> = ["top", "backup-1", "backup-2"]
        let resolution = try await RecapExpectedSongsLogic.resolveExpectedIds(
            initial: ["top"],
            backups: ["backup-1", "backup-2", "backup-3"],
            alreadyKnownAlive: { _ in false },
            resolve: { id in dead.contains(id) ? nil : id }
        )

        XCTAssertEqual(resolution.finalIds, ["backup-3"])
    }

    func testExhaustedBackupsDropTheSlotWithoutCrashing() async throws {
        let resolution = try await RecapExpectedSongsLogic.resolveExpectedIds(
            initial: ["a", "b"],
            backups: [],
            alreadyKnownAlive: { _ in false },
            resolve: { (_: String) -> String? in nil } // alles tot, keine Backups übrig
        )

        XCTAssertEqual(resolution.finalIds, [])
        XCTAssertTrue(resolution.resolvedItems.isEmpty)
    }

    func testAlreadyKnownAliveSkipsResolveEntirely() async throws {
        var resolvedCalls: [String] = []
        let resolution = try await RecapExpectedSongsLogic.resolveExpectedIds(
            initial: ["a", "b"],
            backups: [],
            alreadyKnownAlive: { $0 == "a" },
            resolve: { id in resolvedCalls.append(id); return id }
        )

        XCTAssertEqual(resolution.finalIds, ["a", "b"])
        XCTAssertEqual(resolvedCalls, ["b"])
        // "a" wurde nie aufgelöst — kein resolvedItems-Eintrag, obwohl es im finalen Ergebnis steht.
        XCTAssertNil(resolution.resolvedItems["a"])
    }

    func testBackupAlreadyKnownAliveIsAcceptedWithoutResolving() async throws {
        var resolvedCalls: [String] = []
        let resolution = try await RecapExpectedSongsLogic.resolveExpectedIds(
            initial: ["dead"],
            backups: ["already-in-playlist"],
            alreadyKnownAlive: { $0 == "already-in-playlist" },
            resolve: { (id: String) -> String? in resolvedCalls.append(id); return nil }
        )

        XCTAssertEqual(resolution.finalIds, ["already-in-playlist"])
        XCTAssertEqual(resolvedCalls, ["dead"])
    }

    func testBackupsAreNeverUsedTwiceAcrossMultipleReplacements() async throws {
        let dead: Set<String> = ["a", "b"]
        let resolution = try await RecapExpectedSongsLogic.resolveExpectedIds(
            initial: ["a", "b"],
            backups: ["shared-backup", "second-backup"],
            alreadyKnownAlive: { _ in false },
            resolve: { id in dead.contains(id) ? nil : id }
        )

        // Beide toten Slots bekommen je einen eigenen Backup-Ersatz, keiner wird doppelt vergeben.
        XCTAssertEqual(resolution.finalIds, ["shared-backup", "second-backup"])
    }
}
