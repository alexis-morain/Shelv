import SwiftUI

/// A cell in the artist Top Songs shelf: rank (swapped for the "now playing"
/// waveform when this song is the one playing), the shared song row, and an
/// explicit "..." menu button instead of long-press/swipe. This shelf lives
/// inside a horizontally scrolling grid, where long-press and swipe conflict
/// with the grid's own gesture recognizer rather than being recognized
/// reliably; the "..." button sidesteps that entirely.
struct ArtistTopSongCell: View {
    let rank: Int
    let song: Song
    let accentColor: Color
    let isOffline: Bool
    let isFavorite: Bool
    let onPlay: () -> Void
    let onFavorite: () -> Void
    let onAddToPlaylist: () -> Void
    let onPlayNext: () -> Void
    let onAddToQueue: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onPlay) {
                HStack(spacing: 10) {
                    NowPlayingIndicator(
                        songId: song.id,
                        fallbackIndex: rank,
                        accentColor: accentColor,
                        width: 20,
                        alignment: .leading
                    )
                    LibraryStarredSongRow(song: song)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            SongMenuButton(
                song: song,
                isOffline: isOffline,
                isFavorite: isFavorite,
                onPlay: onPlay,
                onFavorite: onFavorite,
                onAddToPlaylist: onAddToPlaylist,
                onPlayNext: onPlayNext,
                onAddToQueue: onAddToQueue
            )
        }
    }
}
