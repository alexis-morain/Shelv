import XCTest

final class ArtistTopSongsRankingTests: XCTestCase {
    func testServerRankingKeepsServerOrderAndDropsRepeatedTitles() {
        let songs = [
            Song(id: "1", title: "Yellow", playCount: 2),
            Song(id: "2", title: "Sparks", playCount: 99),
            // Same track from a compilation: the server returns both.
            Song(id: "3", title: "yellow ", playCount: 1),
            Song(id: "4", title: "Trouble")
        ]

        let ranked = ArtistTopSongsRanking.rankServerSongs(songs)

        XCTAssertEqual(ranked.map { $0.id }, ["1", "2", "4"])
    }

    func testServerRankingHonoursTheLimit() {
        let songs = (1...12).map { Song(id: "\($0)", title: "Track \($0)") }

        XCTAssertEqual(ArtistTopSongsRanking.rankServerSongs(songs, limit: 5).count, 5)
        XCTAssertEqual(ArtistTopSongsRanking.rankServerSongs(songs).count, ArtistTopSongsRanking.limit)
    }

    func testPlayCountFallbackOrdersByPlayCountAndIgnoresUnplayedTracks() {
        let songs = [
            Song(id: "1", title: "Never played"),
            Song(id: "2", title: "Played twice", playCount: 2),
            Song(id: "3", title: "Played once", playCount: 1),
            Song(id: "4", title: "Played a lot", playCount: 40),
            Song(id: "5", title: "Played zero times", playCount: 0)
        ]

        let ranked = ArtistTopSongsRanking.rankByPlayCount(songs)

        XCTAssertEqual(ranked.map { $0.id }, ["4", "2", "3"])
    }

    func testPlayCountFallbackReturnsNothingWhenNoTrackWasEverPlayed() {
        let songs = [
            Song(id: "1", title: "One"),
            Song(id: "2", title: "Two", playCount: 0)
        ]

        XCTAssertTrue(ArtistTopSongsRanking.rankByPlayCount(songs).isEmpty)
    }

    func testPlayCountFallbackKeepsTheMostPlayedCopyOfADuplicatedTitle() {
        let songs = [
            Song(id: "album", title: "Peace", playCount: 12),
            Song(id: "single", title: "PEACE", playCount: 3)
        ]

        XCTAssertEqual(ArtistTopSongsRanking.rankByPlayCount(songs).map { $0.id }, ["album"])
    }

    func testFallbackScansTheMostPlayedAlbumsFirstAndCapsTheFanOut() {
        let albums = (1...40).map { (index: Int) in
            Album(id: "\(index)", name: "Album \(index)", playCount: index)
        }

        let scanned = ArtistTopSongsRanking.fallbackAlbums(from: albums)

        XCTAssertEqual(scanned.count, ArtistTopSongsRanking.fallbackAlbumLimit)
        XCTAssertEqual(scanned.first?.id, "40")
        XCTAssertEqual(scanned.last?.id, "16")
    }

    func testFallbackHandlesAlbumsWithoutPlayCounts() {
        let albums = [
            Album(id: "unplayed", name: "Unplayed"),
            Album(id: "played", name: "Played", playCount: 5)
        ]

        XCTAssertEqual(ArtistTopSongsRanking.fallbackAlbums(from: albums).first?.id, "played")
    }
}
