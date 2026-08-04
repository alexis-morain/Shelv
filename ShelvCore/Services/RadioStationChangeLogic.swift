import Foundation

/// Streaming data (name/URL) is server state — editing it is the only part of a radio
/// station edit that requires an admin-only Subsonic call. AzuraCast config is local/iCloud
/// state. Detecting which side actually changed lets the caller skip the (admin-gated)
/// server call entirely when only AzuraCast fields were touched, and vice versa.
nonisolated enum RadioStationChangeLogic {
    struct Changes: Equatable, Sendable {
        let streamingChanged: Bool
        let azuraCastChanged: Bool

        var hasChanges: Bool { streamingChanged || azuraCastChanged }
    }

    /// - Parameters:
    ///   - normalizedName: the new name, already validated/trimmed (see `RadioStationStore.validate`).
    ///   - normalizedStreamURL: the new stream URL, already validated/trimmed.
    ///   - trimmedAzuraCastAPIURL: the new AzuraCast API URL, already whitespace-trimmed.
    static func detectChanges(
        currentItem: RadioStationDisplayItem,
        normalizedName: String,
        normalizedStreamURL: String,
        useAzuraCastAPI: Bool,
        trimmedAzuraCastAPIURL: String,
        showSongCover: Bool
    ) -> Changes {
        // `currentItem.name` is a raw passthrough of the server's stored name (not
        // necessarily trimmed — other Subsonic clients don't guarantee that), while
        // `normalizedName` always is. Trim both sides so a station with incidental
        // whitespace in its stored name doesn't false-positive as "streaming changed"
        // on every save, which would wrongly route an AzuraCast-only edit through the
        // admin-gated server call.
        let streamingChanged = normalizedName != currentItem.name.trimmingCharacters(in: .whitespacesAndNewlines)
            || RadioStationMetadata.normalizedStreamURL(normalizedStreamURL) != RadioStationMetadata.normalizedStreamURL(currentItem.streamURL)
        let azuraCastChanged = useAzuraCastAPI != currentItem.metadata.useAzuraCastAPI
            || trimmedAzuraCastAPIURL != currentItem.metadata.azuraCastAPIURL
            || showSongCover != currentItem.metadata.showSongCover
        return Changes(streamingChanged: streamingChanged, azuraCastChanged: azuraCastChanged)
    }
}
