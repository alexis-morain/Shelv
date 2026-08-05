#if os(iOS) || os(tvOS)
import Intents
import OSLog
#if os(iOS) && compiler(>=6.4) && canImport(AppIntents) && canImport(MediaIntents)
import AppIntents
import MediaIntents
#endif

/// Supplies the affinity signals Siri uses when choosing between Shelv and
/// Apple Music. Siri-triggered playback is deliberately excluded because the
/// system already records those interactions itself.
@MainActor
final class SiriMediaAppSelectionService {
    static let shared = SiriMediaAppSelectionService()

    private struct PendingDonation {
        let generation: Int
        let intent: INPlayMediaIntent
        let catalogItem: ShelvIntentCatalogItem
        let shuffled: Bool
    }

    private let logger = Logger(
        subsystem: "ch.vkugler.Shelv",
        category: "SiriAppSelection"
    )
    private let libraryItemCountDefaultsKey = "siri.mediaUserContext.libraryItemCount"
    private var systemIntentDepth = 0
    private var pendingDonation: PendingDonation?

    private init() {}

    var isHandlingSystemIntent: Bool { systemIntentDepth > 0 }

    func beginSystemIntent() {
        systemIntentDepth += 1
        pendingDonation = nil
    }

    func endSystemIntent() {
        systemIntentDepth = max(0, systemIntentDepth - 1)
    }

    var authorizationStatus: INSiriAuthorizationStatus {
        INPreferences.siriAuthorizationStatus()
    }

    /// Asks for Siri access, which SiriKit requires before it hands a media
    /// request to the app at all.
    ///
    /// Without this call the status stays `.notDetermined`: iOS never shows the
    /// prompt, no Siri switch appears in Shelv's settings, and every spoken
    /// playback request fails before it ever reaches this process. App Shortcuts
    /// are unaffected, which is why opening the app by voice always worked while
    /// "play something in Shelv" did not.
    func requestAuthorizationIfNeeded() {
        let status = INPreferences.siriAuthorizationStatus()
        guard status == .notDetermined else {
            logger.notice("Siri authorization status=\(status.rawValue, privacy: .public)")
            return
        }
        let logger = self.logger
        INPreferences.requestSiriAuthorization { resolved in
            logger.notice(
                "Siri authorization resolved status=\(resolved.rawValue, privacy: .public)"
            )
        }
    }

    /// Announces Shelv as a media app on every launch, before any library work.
    ///
    /// This must not wait for the library: publishing it is what makes Siri
    /// consider Shelv for playback at all. The refined count follows later, but
    /// on a fresh install — or whenever the library chain is cut short by a slow
    /// server or a cancelled task — this is the only signal Siri gets.
    func restoreUserContext() {
        let count = UserDefaults.standard.object(
            forKey: libraryItemCountDefaultsKey
        ) as? Int
        publishUserContext(
            numberOfLibraryItems: count ?? 0,
            source: count == nil ? "launch" : "restored"
        )
    }

    func updateUserContext(numberOfLibraryItems: Int) {
        let count = max(0, numberOfLibraryItems)
        UserDefaults.standard.set(count, forKey: libraryItemCountDefaultsKey)
        publishUserContext(numberOfLibraryItems: count, source: "library")
    }

    func confirmPlayableCatalog(minimumItemCount: Int) {
        guard minimumItemCount > 0 else { return }
        let cachedCount = UserDefaults.standard.object(
            forKey: libraryItemCountDefaultsKey
        ) as? Int ?? 0
        guard cachedCount <= 0 else { return }
        let count = max(1, minimumItemCount)
        UserDefaults.standard.set(count, forKey: libraryItemCountDefaultsKey)
        publishUserContext(numberOfLibraryItems: count, source: "audioSearch")
    }

    private func publishUserContext(numberOfLibraryItems: Int, source: String) {
        let context = INMediaUserContext()
        // subscriptionStatus describes whether this person can play content in
        // the app — not whether the app sells a subscription. With a server
        // configured they can play their whole library, and saying so is what
        // lets Siri pick Shelv over Apple Music. Reporting `.unknown` here made
        // Siri treat Shelv as an app with no usable catalog.
        context.subscriptionStatus = SubsonicAPIService.shared.activeServer == nil
            ? .notSubscribed
            : .subscribed
        context.numberOfLibraryItems = numberOfLibraryItems
        context.becomeCurrent()
        logger.notice(
            "Media user context published source=\(source, privacy: .public) items=\(numberOfLibraryItems, privacy: .public) subscribed=\(SubsonicAPIService.shared.activeServer != nil, privacy: .public)"
        )
    }

    func prepareMusicDonation(
        songs: [Song],
        startIndex: Int,
        shuffled: Bool,
        generation: Int
    ) {
        guard !isHandlingSystemIntent,
              songs.indices.contains(startIndex)
        else { return }

        let selected = songs[startIndex]
        let mediaItem = INMediaItem(
            identifier: selected.id,
            title: selected.title,
            type: .song,
            artwork: nil
        )
        let search = INMediaSearch(
            mediaType: .song,
            sortOrder: .unknown,
            mediaName: selected.title,
            artistName: selected.artist,
            albumName: selected.album,
            genreNames: selected.genre.map { [$0] },
            moodNames: selected.moods,
            releaseDate: nil,
            reference: .unknown,
            mediaIdentifier: selected.id
        )
        let intent = INPlayMediaIntent(
            mediaItems: [mediaItem],
            mediaContainer: inferredContainer(for: songs),
            playShuffled: shuffled,
            playbackRepeatMode: .none,
            resumePlayback: false,
            playbackQueueLocation: .now,
            playbackSpeed: nil,
            mediaSearch: search
        )
        let catalogItem = ShelvIntentCatalogItem(
            reference: ShortcutPlayableReference(
                serverConfigID: SubsonicAPIService.shared.activeServer?.id.uuidString ?? "",
                kind: .song,
                contentID: selected.id
            ),
            title: selected.title,
            artistID: selected.artistId,
            artistName: selected.artist,
            albumID: selected.albumId,
            albumTitle: selected.album,
            duration: selected.duration.map(TimeInterval.init),
            itemCount: nil,
            internationalStandardRecordingCode: selected.isrc?.first
        )
        pendingDonation = PendingDonation(
            generation: generation,
            intent: intent,
            catalogItem: catalogItem,
            shuffled: shuffled
        )
    }

    func prepareRadioDonation(
        station: RadioStationDisplayItem,
        generation: Int
    ) {
        guard !isHandlingSystemIntent else { return }
        let mediaItem = INMediaItem(
            identifier: station.id,
            title: station.name,
            type: .radioStation,
            artwork: nil
        )
        let search = INMediaSearch(
            mediaType: .radioStation,
            sortOrder: .unknown,
            mediaName: station.name,
            artistName: nil,
            albumName: nil,
            genreNames: nil,
            moodNames: nil,
            releaseDate: nil,
            reference: .unknown,
            mediaIdentifier: station.id
        )
        let intent = INPlayMediaIntent(
            mediaItems: [mediaItem],
            mediaContainer: nil,
            playShuffled: false,
            playbackRepeatMode: .none,
            resumePlayback: false,
            playbackQueueLocation: .now,
            playbackSpeed: nil,
            mediaSearch: search
        )
        let catalogItem = ShelvIntentCatalogItem(
            reference: ShortcutPlayableReference(
                serverConfigID: SubsonicAPIService.shared.activeServer?.id.uuidString ?? "",
                kind: .radio,
                contentID: station.id
            ),
            title: station.name,
            artistID: nil,
            artistName: nil,
            albumID: nil,
            albumTitle: nil,
            duration: nil,
            itemCount: nil,
            internationalStandardRecordingCode: nil
        )
        pendingDonation = PendingDonation(
            generation: generation,
            intent: intent,
            catalogItem: catalogItem,
            shuffled: false
        )
    }

    func playbackDidStart(generation: Int) {
        guard !isHandlingSystemIntent,
              let pendingDonation,
              pendingDonation.generation == generation
        else { return }
        self.pendingDonation = nil

        Task {
            do {
                try await INInteraction(intent: pendingDonation.intent, response: nil).donate()
                logger.notice("Legacy media interaction donated")
            } catch {
                logger.error(
                    "Media interaction donation failed error=\(String(describing: error), privacy: .private(mask: .hash))"
                )
            }

            await donateNativePlayback(
                item: pendingDonation.catalogItem,
                shuffled: pendingDonation.shuffled
            )
        }
    }

    func playbackDidFail(generation: Int) {
        guard pendingDonation?.generation == generation else { return }
        pendingDonation = nil
    }

    private func inferredContainer(for songs: [Song]) -> INMediaItem? {
        guard let first = songs.first else { return nil }

        if let albumID = first.albumId,
           !albumID.isEmpty,
           let album = first.album,
           !album.isEmpty,
           songs.allSatisfy({ $0.albumId == albumID }) {
            return INMediaItem(
                identifier: albumID,
                title: album,
                type: .album,
                artwork: nil
            )
        }

        if let artistID = first.artistId,
           !artistID.isEmpty,
           let artist = first.artist,
           !artist.isEmpty,
           songs.allSatisfy({ $0.artistId == artistID }) {
            return INMediaItem(
                identifier: artistID,
                title: artist,
                type: .artist,
                artwork: nil
            )
        }

        return nil
    }

    /// Publishes the track that just started as the now-playing audio entity.
    /// Called for every track, whoever started it — an entity that lags behind
    /// the queue would make "add this song to my playlist" hit the wrong song.
    func updateNowPlayingRelevance(song: Song) {
        guard let serverConfigID = SubsonicAPIService.shared.activeServer?.id.uuidString else {
            return
        }
        let item = ShelvIntentCatalogItem(
            reference: ShortcutPlayableReference(
                serverConfigID: serverConfigID,
                kind: .song,
                contentID: song.id
            ),
            title: song.title,
            artistID: song.artistId,
            artistName: song.artist,
            albumID: song.albumId,
            albumTitle: song.album,
            duration: song.duration.map(TimeInterval.init),
            itemCount: nil,
            internationalStandardRecordingCode: song.isrc?.first
        )
        Task { await publishNowPlayingRelevance(item: item) }
    }

    func updateNowPlayingRelevance(station: RadioStationDisplayItem) {
        guard let serverConfigID = SubsonicAPIService.shared.activeServer?.id.uuidString else {
            return
        }
        let item = ShelvIntentCatalogItem(
            reference: ShortcutPlayableReference(
                serverConfigID: serverConfigID,
                kind: .radio,
                contentID: station.id
            ),
            title: station.name,
            artistID: nil,
            artistName: nil,
            albumID: nil,
            albumTitle: nil,
            duration: nil,
            itemCount: nil,
            internationalStandardRecordingCode: nil
        )
        Task { await publishNowPlayingRelevance(item: item) }
    }

    /// Publishes what is playing as the now-playing audio entity. iOS 27's Siri
    /// uses this to resolve references such as "add this song to my playlist"
    /// without the person having to name the track again.
    private func publishNowPlayingRelevance(item: ShelvIntentCatalogItem) async {
        #if os(iOS) && compiler(>=6.4) && canImport(AppIntents) && canImport(MediaIntents)
        guard #available(iOS 27.0, *),
              !item.reference.serverConfigID.isEmpty
        else { return }

        let entity: any AppEntity
        switch item.reference.kind {
        case .song:
            entity = ShelvAudioSongEntity(item: item)
        case .radio:
            entity = ShelvAudioRadioEntity(item: item)
        case .album, .artist, .playlist:
            return
        }

        do {
            try await RelevantEntities.shared.updateEntities(
                [entity],
                for: .audio(.nowPlaying)
            )
        } catch {
            logger.error(
                "Now playing relevance update failed error=\(String(describing: error), privacy: .private(mask: .hash))"
            )
        }
        #endif
    }

    private func donateNativePlayback(
        item: ShelvIntentCatalogItem,
        shuffled: Bool
    ) async {
        #if os(iOS) && compiler(>=6.4) && canImport(AppIntents) && canImport(MediaIntents)
        guard #available(iOS 27.0, *),
              !item.reference.serverConfigID.isEmpty
        else { return }

        let audioEntity: ShelvAudioEntity
        switch item.reference.kind {
        case .song:
            audioEntity = .song(ShelvAudioSongEntity(item: item))
        case .radio:
            audioEntity = .radio(ShelvAudioRadioEntity(item: item))
        case .album, .artist, .playlist:
            return
        }

        do {
            let intent = ShelvPlayAudioIntent()
            intent.audioEntity = audioEntity
            intent.playbackAttributes = shuffled ? [.shuffle] : []
            intent.warmupAudioQueueResult = nil
            intent.queueLocation = nil
            _ = try await IntentDonationManager.shared.donate(intent: intent)
            logger.notice(
                "Native media interaction donated kind=\(item.reference.kind.rawValue, privacy: .public)"
            )
        } catch {
            logger.error(
                "Native media interaction donation failed error=\(String(describing: error), privacy: .private(mask: .hash))"
            )
        }
        #endif
    }
}
#endif
