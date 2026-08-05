#if compiler(>=6.4) && canImport(MediaIntents) && !os(tvOS) && !os(watchOS)
import AppIntents
import Foundation
import MediaIntents

/// The remaining audio-domain schemas Shelv can honor. `playAudio` and
/// `createStation` live in ``ShelvMediaAppIntents``; these four cover preparing
/// a queue and the library edits people ask for by voice.
///
/// Adopting `warmupAudioQueue` matters more than it looks: Siri calls it while
/// it is still speaking, so the track list is already resolved by the time the
/// play request arrives. On a self-hosted server that is the difference between
/// answering inside the system's deadline and answering after it.

@available(iOS 27.0, macOS 27.0, *)
@AppIntent(schema: .audio.warmupAudioQueue)
struct ShelvWarmupAudioQueueIntent {
    static let title: LocalizedStringResource = "shortcut_media_warmup_title"
    static let description = IntentDescription("shortcut_media_warmup_description")
    static let openAppWhenRun = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    static let supportedModes: IntentModes = .background

    @Parameter(title: "shortcut_playable_parameter")
    var audioEntity: ShelvAudioEntity

    @Parameter(title: "shortcut_playback_attributes_parameter", default: [])
    var playbackAttributes: Set<ShelvAudioPlaybackAttribute>

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ShelvAudioWarmupResult> {
        ShelvIntentDiagnostics.received(route: "audioSchema.warmupAudioQueue")

        // Only a concrete catalog item has a track list worth resolving early.
        // Mixes and instant mixes are generated at play time, so warming them
        // would throw the result away. Reporting success keeps Siri moving.
        if let reference = audioEntity.reference {
            do {
                try await ShelvSystemIntentPlaybackService.shared.warmUpQueue(for: reference)
            } catch let error as ShortcutPlaybackError {
                // A failed warmup must not fail the request — the play intent
                // that follows resolves the content again and reports properly.
                ShelvIntentDiagnostics.failed(action: "media.warmup", error: error)
            }
        }
        return .result(value: ShelvAudioWarmupResult())
    }
}

@available(iOS 27.0, macOS 27.0, *)
@AppEnum(schema: .audio.affinityState)
enum ShelvAudioAffinityState: String {
    case like
    case dislike
    case unset

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .like: "shortcut_media_affinity_like",
        .dislike: "shortcut_media_affinity_dislike",
        .unset: "shortcut_media_affinity_unset",
    ]
}

/// Navidrome stores a single starred flag, so "like" stars and both "dislike"
/// and "unset" remove the star. Shelv has no separate dislike list, and
/// inventing one locally would not survive to the server.
@available(iOS 27.0, macOS 27.0, *)
@AppIntent(schema: .audio.updateAudioAffinity)
struct ShelvUpdateAudioAffinityIntent {
    static let title: LocalizedStringResource = "shortcut_media_affinity_title"
    static let description = IntentDescription("shortcut_media_affinity_description")
    static let openAppWhenRun = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    static let supportedModes: IntentModes = .background

    @Parameter(title: "shortcut_media_affinity_parameter")
    var affinityState: ShelvAudioAffinityState

    @Parameter(title: "shortcut_playable_parameter")
    var target: ShelvAudioEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        ShelvIntentDiagnostics.received(route: "audioSchema.updateAudioAffinity")
        guard let reference = target.reference else {
            throw ShortcutPlaybackError.unsupportedLibraryEdit
        }
        try await ShelvIntentLibraryService.shared.setFavorite(
            affinityState == .like,
            for: reference
        )
        return .result()
    }
}

@available(iOS 27.0, macOS 27.0, *)
@AppIntent(schema: .audio.addToLibrary)
struct ShelvAddAudioToLibraryIntent {
    static let title: LocalizedStringResource = "shortcut_media_add_library_title"
    static let description = IntentDescription("shortcut_media_add_library_description")
    static let openAppWhenRun = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    static let supportedModes: IntentModes = .background

    @Parameter(title: "shortcut_playable_parameter")
    var audioEntity: ShelvAudioEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        ShelvIntentDiagnostics.received(route: "audioSchema.addToLibrary")
        guard let reference = audioEntity.reference else {
            throw ShortcutPlaybackError.unsupportedLibraryEdit
        }
        // Everything on the server is already in the library, so the only
        // meaningful reading of "add this" is to mark it as a favorite.
        try await ShelvIntentLibraryService.shared.setFavorite(true, for: reference)
        return .result()
    }
}

@available(iOS 27.0, macOS 27.0, *)
@AppIntent(schema: .audio.addToPlaylist)
struct ShelvAddAudioToPlaylistIntent {
    static let title: LocalizedStringResource = "shortcut_media_add_playlist_title"
    static let description = IntentDescription("shortcut_media_add_playlist_description")
    static let openAppWhenRun = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    static let supportedModes: IntentModes = .background

    @Parameter(title: "shortcut_playable_parameter")
    var audioEntity: ShelvAudioEntity

    @Parameter(title: "shortcut_playlist_parameter")
    var playlist: ShelvAudioPlaylistEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        ShelvIntentDiagnostics.received(route: "audioSchema.addToPlaylist")
        guard let source = audioEntity.reference else {
            throw ShortcutPlaybackError.unsupportedLibraryEdit
        }
        // The smart mixes and the downloads queues are presented as playlists
        // to Siri, but they are computed views and cannot be written to.
        guard let target = playlist.reference else {
            throw ShortcutPlaybackError.unsupportedLibraryEdit
        }
        try await ShelvIntentLibraryService.shared.addToPlaylist(
            playlistID: target.contentID,
            source: source
        )
        return .result()
    }
}
#endif
