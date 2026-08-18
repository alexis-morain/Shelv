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

/// Full-width artist photo behind the name and the playback actions.
///
/// Servers hand out square artist images (Navidrome caps them at 1000 px), so
/// the square is cropped to a band around its centre, where portraits keep the
/// face. Artists without a photo keep the compact header instead.
struct ArtistBannerHeader<Actions: View>: View {
    let coverArtID: String?
    let name: String
    let subtitle: String?
    let footnote: String?
    @ViewBuilder let actions: Actions

    private let height: CGFloat = 240

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GeometryReader { geo in
                CoverArtView(
                    coverArtID: coverArtID,
                    requestSize: 1000,
                    size: geo.size.width,
                    cornerRadius: 0
                )
                .frame(width: geo.size.width, height: geo.size.width)
                .offset(y: -(geo.size.width - height) / 2)
            }
            .frame(height: height)
            .clipped()
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [.clear, Color(nsColor: .windowBackgroundColor)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: 16) {
                    // The wide photo is often a group or a stage shot; the round
                    // portrait is what identifies the artist at a glance.
                    CoverArtView(coverArtID: coverArtID, requestSize: 300, size: 96, isCircle: true)
                        .overlay(Circle().stroke(.background.opacity(0.6), lineWidth: 2))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(name)
                            .font(.largeTitle.bold())
                            .lineLimit(2)
                        if let subtitle {
                            Text(subtitle)
                                .foregroundStyle(.secondary)
                        }
                        if let footnote {
                            Text(footnote)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }

            actions
                .padding(.horizontal, 24)
        }
    }
}

/// A horizontal shelf of releases. Splitting albums from singles reads better
/// than one long grid with a filter on top of it.
struct ArtistReleaseShelf: View {
    let title: String
    let albums: [Album]

    private let itemWidth: CGFloat = 170

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
                .padding(.horizontal, 24)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(albums) { album in
                        NavigationLink(value: album) {
                            AlbumGridItem(album: album)
                                .equatable()
                                .frame(width: itemWidth)
                        }
                        .buttonStyle(.plain)
                        .albumContextMenu(album)
                    }
                }
                .padding(.horizontal, 24)
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
        NavigationLink(value: album) {
            HStack(spacing: 16) {
                CoverArtView(coverArtID: album.coverArt, requestSize: 300, size: 88)

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "latest_release"))
                        .font(.caption.bold())
                        .foregroundStyle(accentColor)
                    Text(album.name)
                        .font(.headline)
                        .lineLimit(2)
                    if !album.displayYear.isEmpty {
                        Text(album.displayYear)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: 520, alignment: .leading)
            .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
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
                Image(systemName: "arrow.up.right").font(.caption2)
                Text(title)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.secondary.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
