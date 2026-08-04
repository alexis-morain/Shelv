import XCTest

final class PlaylistDuplicateCheckerTests: XCTestCase {
    private func makeSong(_ id: String) -> Song {
        Song(id: id, title: "Song \(id)")
    }

    func testNoDuplicatesWhenPlaylistIsEmpty() {
        let duplicates = PlaylistDuplicateChecker.duplicateSongIds(in: [], among: ["a", "b"])
        XCTAssertTrue(duplicates.isEmpty)
    }

    func testNoDuplicatesWhenNoneOfTheCandidatesArePresent() {
        let existing = [makeSong("a"), makeSong("b")]
        let duplicates = PlaylistDuplicateChecker.duplicateSongIds(in: existing, among: ["c", "d"])
        XCTAssertTrue(duplicates.isEmpty)
    }

    func testSingleDuplicateDetected() {
        let existing = [makeSong("a"), makeSong("b")]
        let duplicates = PlaylistDuplicateChecker.duplicateSongIds(in: existing, among: ["b", "c"])
        XCTAssertEqual(duplicates, ["b"])
    }

    func testMultipleDuplicatesDetected() {
        let existing = [makeSong("a"), makeSong("b"), makeSong("c")]
        let duplicates = PlaylistDuplicateChecker.duplicateSongIds(in: existing, among: ["b", "c", "d"])
        XCTAssertEqual(duplicates, ["b", "c"])
    }

    func testAllCandidatesAreDuplicates() {
        let existing = [makeSong("a"), makeSong("b")]
        let duplicates = PlaylistDuplicateChecker.duplicateSongIds(in: existing, among: ["a", "b"])
        XCTAssertEqual(duplicates, ["a", "b"])
    }

    func testDuplicateCandidateIdsInInputAreCollapsed() {
        // Adding the same song twice in one batch (e.g. selecting it twice) shouldn't
        // produce a duplicate count larger than the actual number of distinct songs.
        let existing = [makeSong("a")]
        let duplicates = PlaylistDuplicateChecker.duplicateSongIds(in: existing, among: ["a", "a"])
        XCTAssertEqual(duplicates, ["a"])
    }
}
