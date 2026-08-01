import Foundation

nonisolated struct RecapPlaylistMutationPlan: Equatable {
    let songIdsToAdd: [String]
    let songIndicesToRemove: [Int]

    init?(currentIds: [String], expectedIds: [String]) {
        guard currentIds != expectedIds else { return nil }
        songIdsToAdd = expectedIds
        songIndicesToRemove = Array(currentIds.indices)
    }
}

nonisolated enum PendingDeletionDisposition: Equatable {
    case completed
    case retry
}

nonisolated enum RecapSyncLogic {
    static func isDefinitiveNotFound(code: Int, message: String?) -> Bool {
        code == 70
            || (code == 0 && (message ?? "").localizedCaseInsensitiveContains("not found"))
    }

    static func playlistMatches(
        ids: [String],
        name: String,
        comment: String?,
        expectedIds: [String],
        expectedName: String
    ) -> Bool {
        ids == expectedIds
            && name == expectedName
            && (comment ?? "") == "Shelv Recap"
    }

    static func completedDeletionIDs(
        from dispositions: [String: PendingDeletionDisposition]
    ) -> Set<String> {
        Set(dispositions.compactMap { id, disposition in
            disposition == .completed ? id : nil
        })
    }
}
