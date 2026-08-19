import Foundation

/// Public numbers about an artist, from services outside the music server.
nonisolated struct ArtistExternalStats: Sendable, Equatable {
    /// Distinct Last.fm listeners, all time. Last.fm publishes no monthly figure.
    let listeners: Int?
    /// Position in this month's ListenBrainz sitewide chart, which only covers
    /// the top of the chart. Absent for everyone below it.
    let worldRank: Int?

    static let none = ArtistExternalStats(listeners: nil, worldRank: nil)

    var isEmpty: Bool { listeners == nil && worldRank == nil }
}

nonisolated enum ArtistExternalStatsSettings {
    /// Off by default: this is the only part of the app that talks to a server
    /// other than the user's own.
    static let enabledKey = "showExternalArtistStats"
    /// The user's own Last.fm API key. None is shipped with the app.
    static let lastFMKeyKey = "lastFMAPIKey"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    static var lastFMAPIKey: String {
        (UserDefaults.standard.string(forKey: lastFMKeyKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Reads the ListenBrainz chart and the Last.fm artist page.
///
/// Both are optional extras: a failure, a missing key or a missing MusicBrainz
/// id simply means no numbers, never an error on screen.
actor ArtistExternalStatsService {
    static let shared = ArtistExternalStatsService()

    /// One chart request covers every artist, so it is fetched once a day and
    /// looked up per artist afterwards.
    private static let chartLifetime: TimeInterval = 24 * 60 * 60
    private static let chartSize = 1000
    private static let requestTimeout: TimeInterval = 10

    private var chart: [String: Int] = [:]
    private var chartFetchedAt: Date?
    private var cache: [String: ArtistExternalStats] = [:]

    func stats(artistName: String, musicBrainzId: String?) async -> ArtistExternalStats {
        guard ArtistExternalStatsSettings.isEnabled else { return .none }

        let key = musicBrainzId ?? artistName.lowercased()
        if let cached = cache[key] { return cached }

        async let listeners = lastFMListeners(artistName: artistName)
        async let rank = worldRank(musicBrainzId: musicBrainzId)
        let stats = ArtistExternalStats(listeners: await listeners, worldRank: await rank)
        cache[key] = stats
        return stats
    }

    /// Visible for tests: the chart is a plain ranked list of MusicBrainz ids.
    static func rank(forMusicBrainzId mbid: String?, in orderedIds: [String?]) -> Int? {
        guard let mbid, !mbid.isEmpty else { return nil }
        return orderedIds.firstIndex(of: mbid).map { $0 + 1 }
    }

    private func lastFMListeners(artistName: String) async -> Int? {
        let apiKey = ArtistExternalStatsSettings.lastFMAPIKey
        guard !apiKey.isEmpty, !artistName.isEmpty else { return nil }
        var components = URLComponents(string: "https://ws.audioscrobbler.com/2.0/")
        components?.queryItems = [
            URLQueryItem(name: "method", value: "artist.getinfo"),
            URLQueryItem(name: "artist", value: artistName),
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = components?.url, let data = await fetch(url) else { return nil }
        struct Response: Decodable {
            struct Artist: Decodable {
                struct Stats: Decodable { let listeners: String? }
                let stats: Stats?
            }
            let artist: Artist?
        }
        let listeners = (try? JSONDecoder().decode(Response.self, from: data))?.artist?.stats?.listeners
        return listeners.flatMap(Int.init)
    }

    private func worldRank(musicBrainzId: String?) async -> Int? {
        guard let musicBrainzId, !musicBrainzId.isEmpty else { return nil }
        await refreshChartIfNeeded()
        return chart[musicBrainzId]
    }

    private func refreshChartIfNeeded() async {
        if let chartFetchedAt, Date().timeIntervalSince(chartFetchedAt) < Self.chartLifetime, !chart.isEmpty {
            return
        }
        var components = URLComponents(string: "https://api.listenbrainz.org/1/stats/sitewide/artists")
        components?.queryItems = [
            URLQueryItem(name: "range", value: "month"),
            URLQueryItem(name: "count", value: "\(Self.chartSize)")
        ]
        guard let url = components?.url, let data = await fetch(url) else { return }
        struct Response: Decodable {
            struct Payload: Decodable {
                struct Entry: Decodable { let artist_mbid: String? }
                let artists: [Entry]
            }
            let payload: Payload
        }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else { return }
        var ranks: [String: Int] = [:]
        for (index, entry) in decoded.payload.artists.enumerated() {
            guard let mbid = entry.artist_mbid, ranks[mbid] == nil else { continue }
            ranks[mbid] = index + 1
        }
        chart = ranks
        chartFetchedAt = Date()
    }

    private func fetch(_ url: URL) async -> Data? {
        var request = URLRequest(url: url, timeoutInterval: Self.requestTimeout)
        request.setValue("Shelv", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }
}
