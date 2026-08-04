import XCTest

final class RadioStationChangeLogicTests: XCTestCase {
    private func makeItem(
        name: String = "EDM",
        streamURL: String = "https://radio.example.com/edm",
        useAzuraCastAPI: Bool = false,
        azuraCastAPIURL: String = "",
        showSongCover: Bool = true
    ) -> RadioStationDisplayItem {
        let station = RadioStation(id: "station-1", name: name, streamURL: streamURL)
        let metadata = RadioStationMetadata(
            recordName: "radio.abc.def",
            serverId: "server-1",
            stationId: "station-1",
            streamURLKey: RadioStationMetadata.normalizedStreamURL(streamURL),
            useAzuraCastAPI: useAzuraCastAPI,
            azuraCastAPIURL: azuraCastAPIURL,
            showSongCover: showSongCover
        )
        return RadioStationDisplayItem(station: station, metadata: metadata)
    }

    private func detect(
        item: RadioStationDisplayItem,
        name: String? = nil,
        streamURL: String? = nil,
        useAzuraCastAPI: Bool? = nil,
        azuraCastAPIURL: String? = nil,
        showSongCover: Bool? = nil
    ) -> RadioStationChangeLogic.Changes {
        RadioStationChangeLogic.detectChanges(
            currentItem: item,
            normalizedName: name ?? item.name,
            normalizedStreamURL: streamURL ?? item.streamURL,
            useAzuraCastAPI: useAzuraCastAPI ?? item.metadata.useAzuraCastAPI,
            trimmedAzuraCastAPIURL: azuraCastAPIURL ?? item.metadata.azuraCastAPIURL,
            showSongCover: showSongCover ?? item.metadata.showSongCover
        )
    }

    func testNoChangesDetectedWhenNothingDiffers() {
        let item = makeItem()
        let changes = detect(item: item)

        XCTAssertFalse(changes.streamingChanged)
        XCTAssertFalse(changes.azuraCastChanged)
        XCTAssertFalse(changes.hasChanges)
    }

    func testStreamingChangedOnNameEdit() {
        let item = makeItem()
        let changes = detect(item: item, name: "EDM Radio")

        XCTAssertTrue(changes.streamingChanged)
        XCTAssertFalse(changes.azuraCastChanged)
    }

    func testStreamingChangedOnStreamURLEdit() {
        let item = makeItem()
        let changes = detect(item: item, streamURL: "https://radio.example.com/edm2")

        XCTAssertTrue(changes.streamingChanged)
        XCTAssertFalse(changes.azuraCastChanged)
    }

    func testStreamingUnchangedWhenStreamURLDiffersOnlyByCaseOrTrailingSlash() {
        // normalizedStreamURL lowercases scheme/host — this must not false-positive as
        // a change just because the user's client displays a slightly different casing.
        let item = makeItem(streamURL: "https://Radio.Example.com/edm")
        let changes = detect(item: item, streamURL: "https://radio.example.com/edm")

        XCTAssertFalse(changes.streamingChanged)
    }

    func testStreamingUnchangedWhenStoredNameHasIncidentalWhitespace() {
        // Regression: some Subsonic clients don't trim names on save. The comparison
        // must trim BOTH sides, or every AzuraCast-only edit on such a station would
        // false-positive as a streaming change and wrongly hit the admin-gated call.
        let item = makeItem(name: "  EDM  ")
        let changes = detect(item: item, name: "EDM", useAzuraCastAPI: true)

        XCTAssertFalse(changes.streamingChanged)
        XCTAssertTrue(changes.azuraCastChanged)
    }

    func testAzuraCastChangedOnToggle() {
        let item = makeItem(useAzuraCastAPI: false)
        let changes = detect(item: item, useAzuraCastAPI: true)

        XCTAssertFalse(changes.streamingChanged)
        XCTAssertTrue(changes.azuraCastChanged)
    }

    func testAzuraCastChangedOnAPIURLEdit() {
        let item = makeItem(useAzuraCastAPI: true, azuraCastAPIURL: "https://old.example.com/api")
        let changes = detect(item: item, azuraCastAPIURL: "https://new.example.com/api")

        XCTAssertFalse(changes.streamingChanged)
        XCTAssertTrue(changes.azuraCastChanged)
    }

    func testAzuraCastChangedOnShowSongCoverToggle() {
        let item = makeItem(showSongCover: true)
        let changes = detect(item: item, showSongCover: false)

        XCTAssertFalse(changes.streamingChanged)
        XCTAssertTrue(changes.azuraCastChanged)
    }

    func testBothChangedWhenStreamingAndAzuraCastEditedTogether() {
        let item = makeItem()
        let changes = detect(item: item, name: "New Name", useAzuraCastAPI: true)

        XCTAssertTrue(changes.streamingChanged)
        XCTAssertTrue(changes.azuraCastChanged)
        XCTAssertTrue(changes.hasChanges)
    }
}
