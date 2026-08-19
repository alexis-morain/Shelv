import SwiftUI

extension ArtistReleaseGroup {
    /// Localised in each UI target, the way the other sort and filter enums are.
    var label: String {
        switch self {
        case .all: String(localized: "release_group_all")
        case .albums: String(localized: "albums")
        case .singlesAndEPs: String(localized: "release_group_singles_eps")
        }
    }
}

/// Album / singles filter of the discography section. Only shown when the
/// artist has both kinds of release.
struct ArtistReleaseGroupPicker: View {
    @Binding var selection: ArtistReleaseGroup
    let groups: [ArtistReleaseGroup]

    var body: some View {
        Picker(String(localized: "discography"), selection: $selection) {
            ForEach(groups, id: \.rawValue) { group in
                Text(group.label).tag(group)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

/// Related artists, as the server reports them. Circular covers match the
/// artist rows used everywhere else in the library.
struct ArtistSimilarArtistsRow: View {
    let artists: [Artist]

    private let itemWidth: CGFloat = 104

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(artists) { artist in
                    NavigationLink(destination: ArtistDetailView(artist: artist)) {
                        VStack(spacing: 8) {
                            AlbumArtView(coverArtId: artist.coverArt, size: 300, isCircle: true)
                                .frame(width: itemWidth, height: itemWidth)
                            Text(artist.name)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .frame(width: itemWidth)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .scrollIndicators(.hidden)
    }
}

/// Full-width artist photo behind the name and the playback actions.
///
/// Servers hand out square artist images (Navidrome caps them at 1000 px), so
/// the square is cropped to a band around its centre, where portraits keep the
/// face. Pages whose artist has no image keep the compact header instead.
struct ArtistBannerHeader<Actions: View>: View {
    let artist: Artist
    let subtitle: String?
    /// Public figures from outside the server, when the user asked for them.
    let footnote: String?
    let accentColor: Color
    @ViewBuilder let actions: Actions

    private let height: CGFloat = 260

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GeometryReader { geo in
                AlbumArtView(coverArtId: artist.coverArt, size: 1000, cornerRadius: 0)
                    .frame(width: geo.size.width, height: geo.size.width)
                    .offset(y: -(geo.size.width - height) / 2)
            }
            .frame(height: height)
            .clipped()
            .overlay(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [.clear, Color(UIColor.systemBackground)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: 14) {
                    // The wide photo is often a group or a stage shot; the round
                    // portrait is what identifies the artist at a glance.
                    AlbumArtView(coverArtId: artist.coverArt, size: 300, isCircle: true)
                        .frame(width: 84, height: 84)
                        .overlay(Circle().stroke(.background.opacity(0.6), lineWidth: 2))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(artist.name)
                            .font(.title).bold()
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        if let subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if let footnote {
                            Text(footnote)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }

            actions
                .padding(.horizontal)
        }
    }
}

/// A horizontal shelf of releases, the way the rest of Discover presents
/// albums. Splitting albums from singles reads better than one long grid with
/// a filter on top of it.
struct ArtistReleaseShelf: View {
    let title: String
    let albums: [Album]
    let personalization: PersonalizationSwipeConfiguration

    private let itemWidth: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3).bold()
                .padding(.horizontal)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(albums) { album in
                        NavigationLink(destination: AlbumDetailView(album: album)) {
                            AlbumCardView(
                                album: album,
                                personalization: personalization,
                                showArtist: false,
                                showYear: true
                            )
                            .equatable()
                            .frame(width: itemWidth)
                        }
                        .buttonStyle(.plain)
                        .albumContextMenu(album, showPreview: false)
                    }
                }
                .padding(.horizontal)
            }
            .scrollIndicators(.hidden)
        }
    }
}

/// The artist's newest release, pulled out of the shelves so it is the first
/// thing offered after the top songs.
struct ArtistLatestReleaseCard: View {
    let album: Album
    let accentColor: Color

    var body: some View {
        NavigationLink(destination: AlbumDetailView(album: album)) {
            HStack(spacing: 16) {
                AlbumArtView(coverArtId: album.coverArt, size: 300)
                    .frame(width: 92, height: 92)

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "latest_release"))
                        .font(.caption).bold()
                        .foregroundStyle(accentColor)
                    Text(album.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if !album.displayYear.isEmpty {
                        Text(album.displayYear)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}

/// External pages for the artist, as chips under the biography.
struct ArtistLinksRow: View {
    let lastFmURL: URL?
    let musicBrainzURL: URL?

    var body: some View {
        if lastFmURL != nil || musicBrainzURL != nil {
            HStack(spacing: 10) {
                if let lastFmURL {
                    chip(String(localized: "last_fm"), url: lastFmURL)
                }
                if let musicBrainzURL {
                    chip(String(localized: "musicbrainz"), url: musicBrainzURL)
                }
            }
        }
    }

    private func chip(_ title: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.secondary.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
