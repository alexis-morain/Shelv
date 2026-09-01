import XCTest

final class ArtistPlayOrderTests: XCTestCase {
    private func song(_ id: String) -> Song { Song(id: id, title: "Track \(id)") }

    func testWithoutTopSongsTheDiscographyIsUntouched() {
        let discography = [song("1"), song("2"), song("3")]

        let ordered = ArtistPlayOrder.songs(topSongs: [], discography: discography)

        XCTAssertEqual(ordered.map(\.id), ["1", "2", "3"])
    }

    func testTopSongsLeadInTheirRankedOrder() {
        let ordered = ArtistPlayOrder.songs(
            topSongs: [song("3"), song("1")],
            discography: [song("1"), song("2"), song("3"), song("4")]
        )

        XCTAssertEqual(ordered.map(\.id), ["3", "1", "2", "4"])
    }

    func testASongNeverPlaysTwice() {
        let ordered = ArtistPlayOrder.songs(
            topSongs: [song("2"), song("2")],
            discography: [song("1"), song("2")]
        )

        XCTAssertEqual(ordered.map(\.id), ["2", "1"])
    }

    func testATopSongMissingFromTheDiscographyStillPlays() {
        // getTopSongs can name a track the artist page did not load, for
        // instance when the album list is still coming in.
        let ordered = ArtistPlayOrder.songs(
            topSongs: [song("99")],
            discography: [song("1")]
        )

        XCTAssertEqual(ordered.map(\.id), ["99", "1"])
    }

    func testAnEmptyDiscographyLeavesTheTopSongs() {
        let ordered = ArtistPlayOrder.songs(topSongs: [song("1")], discography: [])

        XCTAssertEqual(ordered.map(\.id), ["1"])
    }
}
