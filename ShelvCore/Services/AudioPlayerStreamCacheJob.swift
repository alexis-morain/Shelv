import Foundation

struct AudioPlayerStreamCacheJob: Sendable {
    let songId: String
    let title: String
    let url: URL
    let codec: String
    let bitrate: Int
}

struct AudioPlayerStreamCacheWindowPlan: Equatable, Sendable {
    /// Retention follows the logical queue window, while scheduling only contains
    /// jobs that can run under the current connectivity conditions. Recently played
    /// songs are kept too — so a quick replay doesn't re-download what was just
    /// evicted — but never scheduled, since that would just re-cache old data no one
    /// asked for.
    let keepSongIds: Set<String>
    let schedulingSignature: [String]

    init(
        currentSongId: String,
        desiredUpcomingSongIds: [String],
        desiredBehindSongIds: [String] = [],
        schedulableJobSongIds: [String]
    ) {
        keepSongIds = Set(desiredUpcomingSongIds)
            .union(desiredBehindSongIds)
            .union([currentSongId])
        schedulingSignature = [currentSongId] + schedulableJobSongIds
    }
}
