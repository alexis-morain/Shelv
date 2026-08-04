import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var result: SearchResult?
    @State private var searchTask: Task<Void, Never>?
    @State private var path = NavigationPath()
    @ObservedObject private var serverStore = ServerStore.shared
    @ObservedObject private var libraryStore = LibraryStore.shared
    @AppStorage("showFavoritesInLibrary") private var showFavoritesInLibrary = true

    private let player = AudioPlayerService.shared

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var matchedFavoriteArtists: [Artist] {
        guard showFavoritesInLibrary, !trimmedQuery.isEmpty else { return [] }
        let q = trimmedQuery.lowercased()
        return libraryStore.favoriteArtists.filter { $0.name.lowercased().contains(q) }
    }

    private var matchedFavoriteAlbums: [Album] {
        guard showFavoritesInLibrary, !trimmedQuery.isEmpty else { return [] }
        let q = trimmedQuery.lowercased()
        return libraryStore.favoriteAlbums.filter {
            $0.name.lowercased().contains(q) || ($0.artist?.lowercased().contains(q) ?? false)
        }
    }

    private var matchedFavoriteSongs: [Song] {
        guard showFavoritesInLibrary, !trimmedQuery.isEmpty else { return [] }
        let q = trimmedQuery.lowercased()
        return libraryStore.favoriteSongs.filter {
            $0.title.lowercased().contains(q) ||
            ($0.artist?.lowercased().contains(q) ?? false) ||
            ($0.album?.lowercased().contains(q) ?? false)
        }
    }

    private var hasFavoriteResults: Bool {
        !matchedFavoriteArtists.isEmpty || !matchedFavoriteAlbums.isEmpty || !matchedFavoriteSongs.isEmpty
    }

    private var hasResults: Bool {
        !(result?.song ?? []).isEmpty ||
        !(result?.album ?? []).isEmpty ||
        !(result?.artist ?? []).isEmpty ||
        hasFavoriteResults
    }

    var body: some View {
        // Bewusst EINE durchgehende vertikale Liste (Künstler → Alben → Titel als Zeilen):
        // verschachtelte horizontale Karussells in einem vertikalen ScrollView sind unter
        // `.searchable` auf tvOS eine Fokus-Falle (der Abwärts-Swipe kommt nicht heraus).
        NavigationStack(path: $path) {
            Group {
                if !trimmedQuery.isEmpty && !hasResults {
                    ContentUnavailableView.search(text: query)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            if let artists = result?.artist.map({
                                $0.filter { ($0.albumCount ?? 0) > 0 }
                            }), !artists.isEmpty {
                                sectionHeader(String(localized: "artists"))
                                ForEach(artists) { artist in
                                    ArtistListRow(
                                        artist: artist,
                                        albumCount: artist.albumCount ?? 0
                                    ) { path.append(artist) }
                                }
                            }
                            if let albums = result?.album, !albums.isEmpty {
                                sectionHeader(String(localized: "albums"))
                                ForEach(albums) { album in
                                    AlbumListRow(album: album) { path.append(album) }
                                }
                            }
                            if let songs = result?.song, !songs.isEmpty {
                                sectionHeader(String(localized: "songs"))
                                ForEach(Array(songs.enumerated()), id: \.element.id) { i, song in
                                    DetailSongRow(song: song, number: i, showArtwork: true) {
                                        player.play(songs: songs, startIndex: i)
                                    }
                                }
                            }
                            if hasFavoriteResults {
                                sectionHeader(String(localized: "favorites"))
                                if !matchedFavoriteSongs.isEmpty {
                                    ForEach(Array(matchedFavoriteSongs.enumerated()), id: \.element.id) { i, song in
                                        DetailSongRow(song: song, number: i, showArtwork: true) {
                                            player.play(songs: matchedFavoriteSongs, startIndex: i)
                                        }
                                    }
                                }
                                if !matchedFavoriteArtists.isEmpty {
                                    ForEach(matchedFavoriteArtists) { artist in
                                        ArtistListRow(
                                            artist: artist,
                                            albumCount: artist.albumCount ?? 0
                                        ) { path.append(artist) }
                                    }
                                }
                                if !matchedFavoriteAlbums.isEmpty {
                                    ForEach(matchedFavoriteAlbums) { album in
                                        AlbumListRow(album: album) { path.append(album) }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 24)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationDestination(for: Album.self) { AlbumDetailView(album: $0) }
            .navigationDestination(for: Artist.self) { ArtistDetailView(artist: $0) }
            .searchable(text: $query, placement: .automatic)
            .onAppear {
                if showFavoritesInLibrary {
                    Task { await libraryStore.loadStarred() }
                }
            }
            .onChange(of: serverStore.activeServerID) { _, _ in
                restartSearchAfterServerChange()
            }
            .onChange(of: serverStore.activeServerRevision) { _, _ in
                restartSearchAfterServerChange()
            }
            .onChange(of: query) { _, q in
                searchTask?.cancel()
                let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { result = nil; return }
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    if Task.isCancelled { return }
                    let requestedServerID = serverStore.activeServerID
                    let requestedServerRevision = serverStore.activeServerRevision
                    let response = try? await SubsonicAPIService.shared.search(query: trimmed)
                    guard !Task.isCancelled,
                          requestedServerID == serverStore.activeServerID,
                          requestedServerRevision == serverStore.activeServerRevision,
                          trimmed == query.trimmingCharacters(in: .whitespacesAndNewlines)
                    else { return }
                    result = response
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title).font(.title3).bold()
            .padding(.horizontal, 50)
            .padding(.top, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func restartSearchAfterServerChange() {
        searchTask?.cancel()
        result = nil
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let requestedServerID = serverStore.activeServerID
        let requestedServerRevision = serverStore.activeServerRevision
        searchTask = Task {
            let response = try? await SubsonicAPIService.shared.search(query: trimmed)
            guard !Task.isCancelled,
                  requestedServerID == serverStore.activeServerID,
                  requestedServerRevision == serverStore.activeServerRevision,
                  trimmed == query.trimmingCharacters(in: .whitespacesAndNewlines)
            else { return }
            result = response
        }
    }
}
