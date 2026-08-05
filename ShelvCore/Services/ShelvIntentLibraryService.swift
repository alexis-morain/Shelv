import Foundation

/// Library edits requested through system intents. It deliberately talks to
/// ``SubsonicAPIService`` and ``ShelvSystemIntentPlaybackService`` only, so the
/// same code serves iOS and macOS without depending on a platform UI store.
@MainActor
final class ShelvIntentLibraryService {
    static let shared = ShelvIntentLibraryService()

    private let api = SubsonicAPIService.shared

    private init() {}

    /// Stars or unstars whatever the person referred to. Songs, albums and
    /// artists each have their own Subsonic parameter; playlists and live
    /// streams have no favorite state on the server.
    func setFavorite(_ isFavorite: Bool, for reference: ShortcutPlayableReference) async throws {
        try await requireActiveServer(matching: reference)
        try await requireNetwork()

        do {
            switch reference.kind {
            case .song:
                if isFavorite {
                    try await api.star(songId: reference.contentID)
                } else {
                    try await api.unstar(songId: reference.contentID)
                }
            case .album:
                if isFavorite {
                    try await api.star(albumId: reference.contentID)
                } else {
                    try await api.unstar(albumId: reference.contentID)
                }
            case .artist:
                if isFavorite {
                    try await api.star(artistId: reference.contentID)
                } else {
                    try await api.unstar(artistId: reference.contentID)
                }
            case .playlist, .radio:
                throw ShortcutPlaybackError.unsupportedLibraryEdit
            }
        } catch let error as ShortcutPlaybackError {
            throw error
        } catch {
            throw ShortcutPlaybackError.remoteFailure(error)
        }

        ShelvIntentDiagnostics.libraryEdit(
            action: isFavorite ? "favorite.add" : "favorite.remove",
            kind: reference.kind,
            count: 1
        )
        NotificationCenter.default.post(
            name: .shelvIntentLibraryDidChange,
            object: ShelvIntentLibraryChange.favorites.rawValue
        )
    }

    /// Appends everything behind `source` to a playlist. Subsonic would happily
    /// append a track that is already there, so songs already in the playlist
    /// are skipped — there is no way to ask about them in a voice request.
    @discardableResult
    func addToPlaylist(
        playlistID: String,
        source: ShortcutPlayableReference
    ) async throws -> Int {
        try await requireActiveServer(matching: source)
        try await requireNetwork()

        let songs = try await ShelvSystemIntentPlaybackService.shared.resolvedSongs(for: source)
        guard !songs.isEmpty else { throw ShortcutPlaybackError.noPlayableContent }

        do {
            let detail = try await api.getPlaylist(id: playlistID)
            let duplicates = PlaylistDuplicateChecker.duplicateSongIds(
                in: detail.songs ?? [],
                among: songs.map(\.id)
            )
            var seen = Set<String>()
            let additions = songs.map(\.id).filter {
                !duplicates.contains($0) && seen.insert($0).inserted
            }
            guard !additions.isEmpty else {
                throw ShortcutPlaybackError.alreadyInPlaylist
            }
            try await api.updatePlaylist(id: playlistID, songIdsToAdd: additions)

            ShelvIntentDiagnostics.libraryEdit(
                action: "playlist.add",
                kind: source.kind,
                count: additions.count
            )
            NotificationCenter.default.post(
                name: .shelvIntentLibraryDidChange,
                object: ShelvIntentLibraryChange.playlists.rawValue
            )
            return additions.count
        } catch let error as ShortcutPlaybackError {
            throw error
        } catch {
            throw ShortcutPlaybackError.remoteFailure(error)
        }
    }

    private func requireActiveServer(matching reference: ShortcutPlayableReference) async throws {
        let serverStore = ServerStore.shared
        await serverStore.waitUntilReady()
        guard let server = serverStore.activeServer else {
            throw ShortcutPlaybackError.noActiveServer
        }
        guard reference.serverConfigID == server.id.uuidString else {
            throw ShortcutPlaybackError.serverChanged
        }
    }

    private func requireNetwork() async throws {
        guard !OfflineModeService.shared.isOffline,
              await NetworkStatus.shared.waitUntilNetworkAvailable()
        else { throw ShortcutPlaybackError.noNetwork }
    }
}

/// What a system intent just changed, so observers reload only that part.
nonisolated enum ShelvIntentLibraryChange: String, Sendable {
    case favorites
    case playlists
}

extension Notification.Name {
    /// Posted after a system intent changed favorites or a playlist, so the
    /// visible library can refresh without polling. The object is a
    /// ``ShelvIntentLibraryChange`` raw value.
    static let shelvIntentLibraryDidChange = Notification.Name("shelvIntentLibraryDidChange")
}
