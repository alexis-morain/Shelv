import XCTest

final class ArtistDiscographyTests: XCTestCase {
    private func album(
        id: String,
        songCount: Int? = nil,
        duration: Int? = nil,
        releaseTypes: [String]? = nil
    ) -> Album {
        Album(id: id, name: "Album \(id)", songCount: songCount, duration: duration, releaseTypes: releaseTypes)
    }

    func testServerReleaseTypesWinOverTrackCount() {
        let longSingle = album(id: "1", songCount: 12, duration: 3_600, releaseTypes: ["single"])
        let shortAlbum = album(id: "2", songCount: 2, duration: 300, releaseTypes: ["Album"])

        XCTAssertEqual(ArtistDiscography.group(for: longSingle), .singlesAndEPs)
        XCTAssertEqual(ArtistDiscography.group(for: shortAlbum), .albums)
    }

    func testReleaseTypesAreCaseAndWhitespaceInsensitive() {
        XCTAssertEqual(ArtistDiscography.group(for: album(id: "1", releaseTypes: [" EP "])), .singlesAndEPs)
        XCTAssertEqual(ArtistDiscography.group(for: album(id: "2", releaseTypes: ["COMPILATION"])), .albums)
    }

    func testEmptyReleaseTypesFallBackToTheHeuristic() {
        XCTAssertNil(ArtistDiscography.declaredGroup(for: album(id: "1", releaseTypes: [])))
        XCTAssertEqual(ArtistDiscography.group(for: album(id: "1", songCount: 2, releaseTypes: [])), .singlesAndEPs)
    }

    func testShortTrackCountsAreSinglesWithoutServerMetadata() {
        XCTAssertEqual(ArtistDiscography.group(for: album(id: "1", songCount: 1, duration: 240)), .singlesAndEPs)
        XCTAssertEqual(ArtistDiscography.group(for: album(id: "2", songCount: 3, duration: 700)), .singlesAndEPs)
    }

    func testShortRunningTimeMakesAnEPButALongOneStaysAnAlbum() {
        XCTAssertEqual(ArtistDiscography.group(for: album(id: "1", songCount: 5, duration: 1_500)), .singlesAndEPs)
        XCTAssertEqual(ArtistDiscography.group(for: album(id: "2", songCount: 5, duration: 2_400)), .albums)
    }

    func testUnknownTrackCountIsTreatedAsAnAlbum() {
        XCTAssertEqual(ArtistDiscography.group(for: album(id: "1")), .albums)
        XCTAssertEqual(ArtistDiscography.group(for: album(id: "2", songCount: 0)), .albums)
    }

    func testFilterKeepsEverythingForTheAllGroup() {
        let albums = [album(id: "1", songCount: 10, duration: 3_000), album(id: "2", songCount: 1)]
        XCTAssertEqual(ArtistDiscography.filter(albums, to: .all).map { $0.id }, ["1", "2"])
        XCTAssertEqual(ArtistDiscography.filter(albums, to: .albums).map { $0.id }, ["1"])
        XCTAssertEqual(ArtistDiscography.filter(albums, to: .singlesAndEPs).map { $0.id }, ["2"])
    }

    func testFilterIsHiddenUnlessBothKindsExist() {
        let onlyAlbums = [album(id: "1", songCount: 10, duration: 3_000)]
        let onlySingles = [album(id: "2", songCount: 1)]
        let mixed = onlyAlbums + onlySingles

        XCTAssertTrue(ArtistDiscography.availableGroups(for: onlyAlbums).isEmpty)
        XCTAssertTrue(ArtistDiscography.availableGroups(for: onlySingles).isEmpty)
        XCTAssertTrue(ArtistDiscography.availableGroups(for: []).isEmpty)
        XCTAssertEqual(ArtistDiscography.availableGroups(for: mixed), ArtistReleaseGroup.allCases)
    }
}
