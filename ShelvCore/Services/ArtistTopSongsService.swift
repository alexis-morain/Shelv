import Foundation

/// Ranked top songs for the artist detail pages.
///
/// The server ranking (`getTopSongs`) comes first: Navidrome backs it with
/// Last.fm and only returns tracks that exist in the library. Servers without
/// that data answer with an empty list, so the play counts the server already
/// reports for the artist's own tracks are used as a fallback ranking. When
/// neither source has anything to rank, the section stays hidden rather than
/// showing an arbitrary track list.
///
/// The ordering itself lives in `ArtistTopSongsRanking`.
nonisolated enum ArtistTopSongsService {
    /// The server's own ranking, which needs nothing but the artist name and can
    /// therefore be fetched in parallel with the artist detail instead of after
    /// it. Empty when the server has no ranking, which is when the caller needs
    /// the album-scanning fallback in `topSongs(albums:)`.
    static func serverRanked(
        artistName: String,
        limit: Int = ArtistTopSongsRanking.limit
    ) async -> [Song] {
        ArtistTopSongsRanking.rankServerSongs(
            await fetchServerRanking(
                artistName: artistName,
                count: ArtistTopSongsRanking.serverScanCount
            ),
            limit: limit
        )
    }

    static func topSongs(
        artistName: String,
        albums: [Album],
        limit: Int = ArtistTopSongsRanking.limit,
        loadAlbumSongs: @escaping @Sendable (String) async -> [Song]
    ) async -> [Song] {
        let ranked = await serverRanked(artistName: artistName, limit: limit)
        guard ranked.isEmpty else { return ranked }

        let scanned = ArtistTopSongsRanking.fallbackAlbums(from: albums)
        guard !scanned.isEmpty else { return [] }

        let songs = await PlaybackContentResolver.artistSongs(
            from: scanned,
            loadAlbumSongs: loadAlbumSongs
        )
        return ArtistTopSongsRanking.rankByPlayCount(songs, limit: limit)
    }

    private static func fetchServerRanking(artistName: String, count: Int) async -> [Song] {
        guard !artistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return (try? await SubsonicAPIService.shared.getTopSongs(
            artistName: artistName,
            count: count,
            retries: 1
        )) ?? []
    }
}
