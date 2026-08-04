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
