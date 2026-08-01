import XCTest

final class PlayLogReconciliationLogicTests: XCTestCase {
    func testIdResolvesRefreshesMetadataRegardlessOfPriorStoredValues() async {
        let outcome = await PlayLogReconciliationLogic.reconcile(
            songId: "song-1",
            storedTitle: "Old Title",
            storedArtist: "Old Artist",
            storedAlbum: "Old Album",
            lookupById: { _ in .found(title: "New Title", artist: "New Artist", album: "New Album") },
            searchCandidates: { _ in XCTFail("Should not search when the id resolves"); return [] }
        )

        XCTAssertEqual(outcome, .refreshed(title: "New Title", artist: "New Artist", album: "New Album"))
    }

    func testIdResolvesWithNoPriorMetadataStillRefreshes() async {
        // Der ganz normale Backfill-Fall: alte Zeile hat nur die ID, noch keine Metadaten.
        let outcome = await PlayLogReconciliationLogic.reconcile(
            songId: "song-1",
            storedTitle: nil,
            storedArtist: nil,
            storedAlbum: nil,
            lookupById: { _ in .found(title: "Title", artist: nil, album: nil) },
            searchCandidates: { _ in [] }
        )

        XCTAssertEqual(outcome, .refreshed(title: "Title", artist: nil, album: nil))
    }

    func testDeadIdWithUniqueMetadataMatchRepairsToNewId() async {
        let outcome = await PlayLogReconciliationLogic.reconcile(
            songId: "old-id",
            storedTitle: "Title",
            storedArtist: "Artist",
            storedAlbum: "Album",
            lookupById: { _ in .definitelyNotFound },
            searchCandidates: { query in
                XCTAssertEqual(query, "Title")
                return [
                    PlayLogSearchCandidate(songId: "new-id", title: "Title", artist: "Artist", album: "Album"),
                    PlayLogSearchCandidate(songId: "unrelated-id", title: "Other Title", artist: "Other Artist", album: nil)
                ]
            }
        )

        XCTAssertEqual(outcome, .repaired(newSongId: "new-id", title: "Title", artist: "Artist", album: "Album"))
    }

    func testDeadIdWithNoMetadataMatchDeletes() async {
        let outcome = await PlayLogReconciliationLogic.reconcile(
            songId: "old-id",
            storedTitle: "Title",
            storedArtist: "Artist",
            storedAlbum: "Album",
            lookupById: { _ in .definitelyNotFound },
            searchCandidates: { _ in [] }
        )

        XCTAssertEqual(outcome, .delete)
    }

    func testDeadIdWithNoStoredMetadataAtAllDeletesImmediately() async {
        // Weder ID noch Namensangaben vorhanden — es gibt nichts mehr, worüber sich der Song
        // wiederfinden ließe.
        var searchCalled = false
        let outcome = await PlayLogReconciliationLogic.reconcile(
            songId: "old-id",
            storedTitle: nil,
            storedArtist: nil,
            storedAlbum: nil,
            lookupById: { _ in .definitelyNotFound },
            searchCandidates: { _ in searchCalled = true; return [] }
        )

        XCTAssertEqual(outcome, .delete)
        XCTAssertFalse(searchCalled)
    }

    func testDeadIdWithAmbiguousMetadataMatchSkipsInsteadOfGuessing() async {
        // Zwei Kandidaten mit identischem Titel+Artist+Album (z.B. Duplikat im selben Album) —
        // ohne stabile ID lässt sich nicht entscheiden, welcher der richtige ist.
        let outcome = await PlayLogReconciliationLogic.reconcile(
            songId: "old-id",
            storedTitle: "Title",
            storedArtist: "Artist",
            storedAlbum: "Album",
            lookupById: { _ in .definitelyNotFound },
            searchCandidates: { _ in
                [
                    PlayLogSearchCandidate(songId: "candidate-1", title: "Title", artist: "Artist", album: "Album"),
                    PlayLogSearchCandidate(songId: "candidate-2", title: "Title", artist: "Artist", album: "Album")
                ]
            }
        )

        XCTAssertEqual(outcome, .skip)
    }

    func testMetadataMatchRequiresAllThreeFieldsIncludingNilAlbum() async {
        // Navidrome garantiert kein Album-Tag — ein Kandidat mit abweichendem (oder fehlendem)
        // Album darf nicht als Treffer zählen, wenn das gespeicherte Album explizit nil war.
        let outcome = await PlayLogReconciliationLogic.reconcile(
            songId: "old-id",
            storedTitle: "Single Title",
            storedArtist: "Artist",
            storedAlbum: nil,
            lookupById: { _ in .definitelyNotFound },
            searchCandidates: { _ in
                [
                    PlayLogSearchCandidate(songId: "wrong-album", title: "Single Title", artist: "Artist", album: "Some Album"),
                    PlayLogSearchCandidate(songId: "right-match", title: "Single Title", artist: "Artist", album: nil)
                ]
            }
        )

        XCTAssertEqual(outcome, .repaired(newSongId: "right-match", title: "Single Title", artist: "Artist", album: nil))
    }

    func testNetworkErrorDuringIdLookupSkipsWithoutTouchingSearch() async {
        var searchCalled = false
        let outcome = await PlayLogReconciliationLogic.reconcile(
            songId: "song-1",
            storedTitle: "Title",
            storedArtist: nil,
            storedAlbum: nil,
            lookupById: { _ in .otherError },
            searchCandidates: { _ in searchCalled = true; return [] }
        )

        XCTAssertEqual(outcome, .skip)
        XCTAssertFalse(searchCalled)
    }
}
