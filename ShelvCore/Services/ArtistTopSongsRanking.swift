import Foundation

/// The ordering rules behind the top-songs section of the artist pages,
/// kept free of any network call so they can be tested on their own.
nonisolated enum ArtistTopSongsRanking {
    /// Songs kept for the section.
    static let limit = 10

    /// Songs shown before the section is expanded.
    static let collapsedLimit = 5

    /// Albums scanned by the play-count fallback, most played first. Artists
    /// with a deep back catalogue would otherwise fan out one album request
    /// per release just to fill a five-row list.
    static let fallbackAlbumLimit = 25

    /// What `getTopSongs` is asked for, which is NOT the number of songs it
    /// answers with: Navidrome reads that many entries from its ranking source
    /// and then keeps the ones that exist in the library. Asking for 10 returned
    /// 2 songs for one artist here, asking for 100 returned 15, at the same
    /// cost of one request. Ask wide, show `limit`.
    static let serverScanCount = 100

    /// The server ranking, kept in the order the server sent it.
    static func rankServerSongs(_ songs: [Song], limit: Int = limit) -> [Song] {
        Array(deduplicatedByTitle(songs).prefix(limit))
    }

    /// The albums worth scanning when the server has no ranking, most played
    /// first so the cap keeps the tracks that can actually reach the top.
    static func fallbackAlbums(from albums: [Album]) -> [Album] {
        Array(
            albums
                .sorted { ($0.playCount ?? 0) > ($1.playCount ?? 0) }
                .prefix(fallbackAlbumLimit)
        )
    }

    /// Fallback ranking: the artist's own tracks ordered by the play counts
    /// reported by the server. Never-played tracks are dropped, an untouched
    /// library has no top songs and should show none.
    static func rankByPlayCount(_ songs: [Song], limit: Int = limit) -> [Song] {
        let played = songs.filter { ($0.playCount ?? 0) > 0 }
        guard !played.isEmpty else { return [] }
        let ordered = played.sorted { ($0.playCount ?? 0) > ($1.playCount ?? 0) }
        return Array(deduplicatedByTitle(ordered).prefix(limit))
    }

    /// Keeps the first occurrence of every title. Libraries routinely hold the
    /// same track on an album, on a single and on a compilation, and a top list
    /// that repeats itself is worse than a shorter one.
    private static func deduplicatedByTitle(_ songs: [Song]) -> [Song] {
        var seen = Set<String>()
        return songs.filter { song in
            let key = song.title
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return seen.insert(key).inserted
        }
    }
}
