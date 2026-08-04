import XCTest

final class SubsonicServerTests: XCTestCase {
    func testSecondaryURLIsNormalizedAndCodable() throws {
        var server = SubsonicServer(
            name: "Home",
            baseURL: " music.example.com ",
            username: "vasco",
            secondaryBaseURL: " music-lan.example.com ",
            activeURLSlot: .secondary
        )

        XCTAssertEqual(server.baseURL, "https://music.example.com")
        XCTAssertEqual(server.secondaryURL, "https://music-lan.example.com")
        XCTAssertTrue(server.isUsingSecondaryURL)
        XCTAssertEqual(server.activeBaseURL, "https://music-lan.example.com")

        let data = try JSONEncoder().encode(server)
        server = try JSONDecoder().decode(SubsonicServer.self, from: data)

        XCTAssertEqual(server.baseURL, "https://music.example.com")
        XCTAssertEqual(server.secondaryURL, "https://music-lan.example.com")
        XCTAssertTrue(server.isUsingSecondaryURL)
    }

    func testRemovingSecondaryURLFallsBackToPrimarySlot() {
        var server = SubsonicServer(
            name: "Home",
            baseURL: "https://music.example.com",
            username: "vasco",
            secondaryBaseURL: "https://music-lan.example.com",
            activeURLSlot: .secondary
        )

        server.secondaryBaseURL = ""
        server.sanitizeURLSlots()

        XCTAssertNil(server.secondaryURL)
        XCTAssertFalse(server.isUsingSecondaryURL)
        XCTAssertEqual(server.activeBaseURL, "https://music.example.com")
    }

    func testDerivedStableIdNormalizesEquivalentServerURLs() {
        let first = SubsonicServer(
            baseURL: "HTTPS://Music.Example.com:443/api/subsonic/",
            username: "vasco"
        )
        let second = SubsonicServer(
            baseURL: "https://music.example.com/api/subsonic",
            username: "vasco"
        )

        XCTAssertEqual(first.derivedStableId, second.derivedStableId)
        XCTAssertTrue(first.derivedStableId.hasPrefix("subsonic-"))
    }

    func testDerivedStableIdIsIndependentOfSecondaryURLAndActiveSlot() {
        let primary = SubsonicServer(
            baseURL: "https://music.example.com",
            username: "vasco"
        )
        let secondary = SubsonicServer(
            baseURL: "https://music.example.com",
            username: "vasco",
            secondaryBaseURL: "https://music.internal",
            activeURLSlot: .secondary
        )

        XCTAssertEqual(primary.derivedStableId, secondary.derivedStableId)
    }

    func testDerivedStableIdSeparatesAccountsAndServerPaths() {
        let base = SubsonicServer(
            baseURL: "https://music.example.com/api/subsonic",
            username: "vasco"
        )
        let otherUser = SubsonicServer(
            baseURL: "https://music.example.com/api/subsonic",
            username: "other"
        )
        let otherServer = SubsonicServer(
            baseURL: "https://music.example.com/other/subsonic",
            username: "vasco"
        )

        XCTAssertNotEqual(base.derivedStableId, otherUser.derivedStableId)
        XCTAssertNotEqual(base.derivedStableId, otherServer.derivedStableId)
    }

    func testMusicLibrarySelectionDefaultsToAllAvailableFolders() {
        XCTAssertEqual(
            MusicLibrarySelectionPolicy.resolvedIDs(
                availableIDs: [1, 2],
                mode: nil
            ),
            [1, 2]
        )
    }

    func testMusicLibrarySelectionRestoresOnlyStillAvailableFolders() {
        XCTAssertEqual(
            MusicLibrarySelectionPolicy.resolvedIDs(
                availableIDs: [2, 3],
                mode: .folders([1, 2])
            ),
            [2]
        )
    }

    func testMusicLibrarySelectionFallsBackToAllWhenStoredFoldersDisappear() {
        XCTAssertEqual(
            MusicLibrarySelectionPolicy.resolvedIDs(
                availableIDs: [3, 4],
                mode: .folders([1, 2])
            ),
            [3, 4]
        )
    }

    func testMusicLibrarySelectionConvertsLegacySubsetToAllLibraries() {
        XCTAssertEqual(
            MusicLibrarySelectionPolicy.resolvedIDs(
                availableIDs: [1, 2, 3],
                mode: .folders([1, 2])
            ),
            [1, 2, 3]
        )
    }

    func testSelectingEveryMusicLibraryPersistsAllMode() throws {
        let mode = MusicLibrarySelectionPolicy.persistedMode(
            selectedIDs: [1, 2],
            availableIDs: [1, 2]
        )
        XCTAssertEqual(mode, .all)

        let encoded = try JSONEncoder().encode(mode)
        XCTAssertEqual(
            try JSONDecoder().decode(MusicLibrarySelectionMode.self, from: encoded),
            .all
        )
    }

    func testSelectingOneMusicLibraryPersistsSingleFolderMode() {
        XCTAssertEqual(
            MusicLibrarySelectionPolicy.persistedMode(
                selectedIDs: [2],
                availableIDs: [1, 2, 3]
            ),
            .folders([2])
        )
    }

    func testMusicLibraryQueryRepeatsSortedFolderParameterAndOmitsAll() {
        let items = MusicLibraryQueryItems.make(folderIDs: [9, 2, 9])

        XCTAssertEqual(items.map(\.name), ["musicFolderId", "musicFolderId"])
        XCTAssertEqual(items.map(\.value), ["2", "9"])
        XCTAssertTrue(MusicLibraryQueryItems.make(folderIDs: nil).isEmpty)
    }

    func testAllSelectedLibrariesUseUnfilteredRequestsAndScopedCaches() {
        let serverID = UUID()
        let snapshot = MusicLibrarySelectionSnapshot(
            serverID: serverID,
            availableFolders: [
                SubsonicMusicFolder(id: 2, name: "Audiobooks"),
                SubsonicMusicFolder(id: 1, name: "Music"),
            ],
            selectedFolderIDs: [1, 2]
        )

        XCTAssertTrue(snapshot.showsSelector)
        XCTAssertTrue(snapshot.selectsAllLibraries)
        XCTAssertFalse(snapshot.appliesFilter)
        XCTAssertNil(snapshot.activeRequestFolderIDs)
        XCTAssertEqual(snapshot.visibleCacheFolderIDs, [1, 2])
        XCTAssertEqual(snapshot.allCacheFolderIDs, [1, 2])
        XCTAssertEqual(snapshot.selectionKey, "\(serverID.uuidString)|all")
    }

    func testSelectedLibrarySubsetScopesRequestsWithoutChangingAllCacheScope() {
        let serverID = UUID()
        let snapshot = MusicLibrarySelectionSnapshot(
            serverID: serverID,
            availableFolders: [
                SubsonicMusicFolder(id: 1, name: "Music"),
                SubsonicMusicFolder(id: 2, name: "Audiobooks"),
            ],
            selectedFolderIDs: [2]
        )

        XCTAssertTrue(snapshot.appliesFilter)
        XCTAssertFalse(snapshot.selectsAllLibraries)
        XCTAssertEqual(snapshot.activeRequestFolderIDs, [2])
        XCTAssertEqual(snapshot.visibleCacheFolderIDs, [2])
        XCTAssertEqual(snapshot.allCacheFolderIDs, [1, 2])
        XCTAssertEqual(snapshot.allSelectionKey, "\(serverID.uuidString)|all")
    }

    func testSingleAccessibleLibraryHidesSelectorButKeepsScopedCache() {
        let snapshot = MusicLibrarySelectionSnapshot(
            serverID: UUID(),
            availableFolders: [
                SubsonicMusicFolder(id: 7, name: "Music")
            ],
            selectedFolderIDs: [7]
        )

        XCTAssertFalse(snapshot.showsSelector)
        XCTAssertFalse(snapshot.appliesFilter)
        XCTAssertNil(snapshot.activeRequestFolderIDs)
        XCTAssertEqual(snapshot.visibleCacheFolderIDs, [7])
        XCTAssertEqual(snapshot.allCacheFolderIDs, [7])
    }

    // MARK: - isAdmin

    func testIsAdminDefaultsToTrueOnInit() {
        let server = SubsonicServer(baseURL: "https://music.example.com", username: "vasco")
        XCTAssertTrue(server.isAdmin)
    }

    func testIsAdminDefaultsToTrueWhenDecodingLegacyPayloadMissingTheKey() throws {
        // Simulates a server object persisted before `isAdmin` existed — must not
        // silently lock out a real admin just because the field predates the flag.
        let legacyJSON = """
        {"id":"\(UUID().uuidString)","name":"Home","baseURL":"https://music.example.com","username":"vasco"}
        """
        let server = try JSONDecoder().decode(SubsonicServer.self, from: Data(legacyJSON.utf8))
        XCTAssertTrue(server.isAdmin)
    }

    func testIsAdminRoundTripsThroughCodable() throws {
        var server = SubsonicServer(baseURL: "https://music.example.com", username: "vasco")
        server.isAdmin = false

        let data = try JSONEncoder().encode(server)
        let decoded = try JSONDecoder().decode(SubsonicServer.self, from: data)

        XCTAssertFalse(decoded.isAdmin)
    }

    // MARK: - radioServerIdentity

    func testRadioServerIdentityIsSharedAcrossDifferentAccountsOnTheSameServer() {
        // Radio station AzuraCast metadata belongs to the station/server, not the
        // logged-in account — two different accounts on the same physical server must
        // resolve to the same identity so they share (not duplicate) that metadata.
        let admin = SubsonicServer(baseURL: "https://music.example.com", username: "admin")
        let guest = SubsonicServer(baseURL: "https://music.example.com", username: "guest")

        XCTAssertEqual(admin.radioServerIdentity, guest.radioServerIdentity)
        XCTAssertNotEqual(admin.radioServerIdentity, admin.derivedStableId)
    }

    func testRadioServerIdentityDiffersAcrossDifferentPhysicalServers() {
        let first = SubsonicServer(baseURL: "https://music.example.com", username: "vasco")
        let second = SubsonicServer(baseURL: "https://other.example.com", username: "vasco")

        XCTAssertNotEqual(first.radioServerIdentity, second.radioServerIdentity)
    }

    func testRadioServerIdentityNormalizesEquivalentURLs() {
        let first = SubsonicServer(baseURL: "HTTPS://Music.Example.com:443/api/subsonic/", username: "vasco")
        let second = SubsonicServer(baseURL: "https://music.example.com/api/subsonic", username: "other")

        XCTAssertEqual(first.radioServerIdentity, second.radioServerIdentity)
        XCTAssertTrue(first.radioServerIdentity.hasPrefix("subsonic-url-"))
    }
}
