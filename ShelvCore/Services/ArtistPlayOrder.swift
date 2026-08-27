import Foundation

/// What the Play button on an artist page should queue.
///
/// Playing the discography in album order sounds arbitrary on a library made of
/// fragments: a listener who owns three tracks of an album gets them before the
/// artist's best known song. Leading with the top songs fixes the order without
/// letting the queue run dry after ten tracks.
nonisolated enum ArtistPlayOrder {
    /// Top songs in their ranked order, then everything else in discography
    /// order. A song appears once, at its earliest position.
    static func songs(topSongs: [Song], discography: [Song]) -> [Song] {
        guard !topSongs.isEmpty else { return discography }

        var seen = Set<String>()
        var ordered: [Song] = []
        ordered.reserveCapacity(topSongs.count + discography.count)

        for song in topSongs + discography where seen.insert(song.id).inserted {
            ordered.append(song)
        }
        return ordered
    }
}
