import Foundation

/// Subsonic's `updatePlaylist` happily appends a song that's already in the playlist,
/// silently creating a duplicate row. Before adding, callers fetch the playlist's current
/// songs and use this to find out which of the candidate ids are already present, so the
/// UI can ask the user whether to skip or keep them.
nonisolated enum PlaylistDuplicateChecker {
    static func duplicateSongIds(in existingSongs: [Song], among songIds: [String]) -> Set<String> {
        let existingIds = Set(existingSongs.map(\.id))
        return Set(songIds).intersection(existingIds)
    }
}
