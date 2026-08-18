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
    static func topSongs(
        artistName: String,
        albums: [Album],
        limit: Int = ArtistTopSongsRanking.limit,
        loadAlbumSongs: @escaping @Sendable (String) async -> [Song]
    ) async -> [Song] {
        let ranked = ArtistTopSongsRanking.rankServerSongs(
            await fetchServerRanking(artistName: artistName, limit: limit),
            limit: limit
        )
        guard ranked.isEmpty else { return ranked }

        let scanned = ArtistTopSongsRanking.fallbackAlbums(from: albums)
        guard !scanned.isEmpty else { return [] }

        let songs = await PlaybackContentResolver.artistSongs(
            from: scanned,
            loadAlbumSongs: loadAlbumSongs
        )
        return ArtistTopSongsRanking.rankByPlayCount(songs, limit: limit)
    }

    private static func fetchServerRanking(artistName: String, limit: Int) async -> [Song] {
        guard !artistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return (try? await SubsonicAPIService.shared.getTopSongs(
            artistName: artistName,
            count: limit,
            retries: 1
        )) ?? []
    }
}
